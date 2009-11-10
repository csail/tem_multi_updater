# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Massachusetts Institute of Technology
# License:: MIT

require 'tem_multi_updater'

require 'logger'
require 'stringio'
require 'test/unit'

class IntegrationTest < Test::Unit::TestCase
  def setup
    super
    @server_addr = 'localhost'
    logger = Logger.new StringIO.new
    @updater = Tem::MultiUpdater::Updater.new logger, @server_addr

    @old_abort = Thread.abort_on_exception
    Thread.abort_on_exception = true
  end
  
  def teardown
    Thread.abort_on_exception = @old_abort
    super    
  end
  
  def test_live
    # Remove the TEM firmware from the first card to force an update.
    transport_configs = Tem::MultiProxy::Client.query_tems @server_addr
    assert transport_configs, "#{@server_addr} test proxy is not live"
    assert !transport_configs.empty?, "#{@server_addr} test proxy has no cards"    
    card = @updater.transport_for_config transport_configs[0]
    assert card,
           "Cannot connect to the first card on the #{@server_addr} test proxy"
    class <<card; include Smartcard::Gp::GpCardMixin; end
    card.delete_application Tem::Firmware::Uploader.applet_aid
    card.disconnect
    
    # Run the whole update code against a live proxy.
    assert_equal true, @updater.run,
                 'Integration test needs a live tem_multi_proxy at localhost'
    
    # Check that the first card has the TEM firmware now.
    card = @updater.transport_for_config transport_configs[0]
    assert card, 'Transport error on the card whose TEM firmware was removed'
    tem = Tem::Session.new card
    assert_equal Tem::Firmware::Uploader.fw_version, tem.fw_version,
                 'Incorrect TEM firmware version'
    tem.disconnect
    card.disconnect
  end
end
