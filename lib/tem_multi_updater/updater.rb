# Updates the TEM firmware in all the smartcards on tem_multi_proxy server.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Massachusetts Institute of Technology
# License:: MIT

require 'thread'

# :nodoc: namespace
module Tem::MultiUpdater


# Updates the TEM firmware in all the smartcards on tem_multi_proxy server.
class Updater
  # Creates a multi-proxy firmware updater.
  #
  # Args:
  #   logger:: receives update progress notifications
  #   multiproxy_server_addr:: the address (host or host:port) of the
  #                            tem_multi_proxy RPC port
  def initialize(logger, multiproxy_server_addr, options = {})
    @logger = logger
    @server_addr = multiproxy_server_addr
    @options = options
    @pending = nil
    @pending_mx, @pending_cv = Mutex.new, ConditionVariable.new
  end

  # Runs the multi-proxy update.
  def run
    return unless @pending.nil?
    
    @logger.info "Querying tem_multi_proxy at #{@server_addr}"
    @transport_configs = Tem::MultiProxy::Client.query_tems @server_addr
    if @transport_configs.nil? || @transport_configs.empty?
      @logger.error "No response from tem_multi_proxy at #{@server_addr}"
      return false
    end
    
    spawn_threads
    wait_for_threads
    return true
  end

  # Spawns one updating thread for each smart-card transport configuration.
  def spawn_threads
    @pending = @transport_configs.length
    @transport_configs.each do |transport_config|
      Thread.new(transport_config) do |config|
        update_thread config
      end
    end
  end
  
  # Waits for all the updating threads to complete.
  def wait_for_threads
    @pending_mx.synchronize do
      loop do
        break if @pending == 0
        @pending_cv.wait @pending_mx
      end
    end
  end
  
  # Main method for a TEM firmware updating thread.
  #
  # Args:
  #   transport_config:: configuration for the TEM's smart-card transport 
  def update_thread(transport_config)
    begin
      transport = transport_for_config transport_config
      if transport
        @logger.info "Connected to #{transport.inspect}"
        update_transport transport
        transport.disconnect
      else
        @logger.warn "Failed connecting to #{transport_config.inspect}"
      end
    ensure    
      @pending_mx.synchronize do
        @pending -= 1
        @pending_cv.signal
      end
    end
  end
  
  # Creates a ISO smart-card transport out of a configuration.
  #
  # Args:
  #   transport_config:: configuration for the TEM's smart-card transport
  #
  # Returns a transport.
  def transport_for_config(transport_config)
    Smartcard::Iso::AutoConfigurator.try_transport transport_config    
  end
  
  # Installs or updates TEM firmware on a smart-card.
  # 
  # No firmware will be uploaded if the smart-card already has the latest
  # version of the TEM software.
  #
  # Args:
  #   transport_config:: smart-card transport connecting to the TEM card
  #
  # Returns 
  def update_transport(transport)
    if !needs_update? transport
      @logger.info "No update needed at #{transport.inspect}"
      return false
    end
    
    @logger.info "Uploading TEM firmware to #{transport.inspect}"
    begin
      Tem::Firmware::Uploader.upload_cap transport
      return true
    rescue Exception => e
      @logger.error "Error while uploading TEM firmware to " +
                    "#{transport.inspect} - #{e.class.name}: #{e.message}"
      @logger.info e.backtrace.join("\n")
      return false
    end
  end

  # Checks if the a smart-card needs a TEM firmware upload.
  #
  # Args:
  #   transport_config:: smart-card transport connecting to the TEM card 
  def needs_update?(transport)
    return true if @options[:force]
    
    begin
      tem = Tem::Session.new transport
      tem_version = tem.fw_version
      local_version = Tem::Firmware::Uploader.fw_version
      if local_version[:major] != tem_version[:major]
        return local_version[:major] > tem_version[:major]
      end
      return local_version[:minor] > tem_version[:minor]
    rescue Smartcard::Iso::ApduError
      # An APDU error here means the TEM firmware was not installed.
      return true       
    end
  end
end  # class Tem::MultiUpdater::Updater

end  # namespace Tem::MultiUpdater
