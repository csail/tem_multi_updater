# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Massachusetts Institute of Technology
# License:: MIT

require 'tem_multi_updater'

require 'logger'
require 'stringio'
require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'

class UpdaterTest < Test::Unit::TestCase
  def setup
    super
    @server_addr = :server_addr
    @updater = Tem::MultiUpdater::Updater.new Logger.new(StringIO.new),
                                              @server_addr
    @old_abort = Thread.abort_on_exception
    Thread.abort_on_exception = true
  end
  
  def teardown
    Thread.abort_on_exception = @old_abort
    super
  end
  
  def test_dead_proxy
    flexmock(Tem::MultiProxy::Client).should_receive(:query_tems).
        with(@server_addr).and_return(nil)
    assert_equal false, @updater.run
  end
  
  def test_threading
    flexmock(Tem::MultiProxy::Client).should_receive(:query_tems).
        with(@server_addr).and_return([:transport1, :transport2, :transport3])
    ['1', '2', '3'].each do |suffix|
      tem = Object.new
      flexmock(Smartcard::Iso::AutoConfigurator).should_receive(:try_transport).
          with(:"transport#{suffix}").and_return(tem).once
      flexmock(@updater).should_receive(:update_transport).once.
          with(tem).and_return { Kernel.sleep 0.4 + 0.1 * suffix.to_i; true }          
      flexmock(tem).should_receive(:disconnect).once
    end        
    
    time0 = Time.now
    assert_equal true, @updater.run, 'run return value'
    assert_operator 0.9, :>, Time.now - time0, 'Updates happened in parallel'
  end
    
  def test_update_transport
    flexmock(@updater).should_receive(:needs_update?).with(:new_transport).
                       and_return(false).once
    flexmock(Tem::Firmware::Uploader).should_receive(:upload_cap).
                                      with(:new_transport).never
    assert_equal false, @updater.update_transport(:new_transport),
                 'Up-to-date smartcard'

    flexmock(@updater).should_receive(:needs_update?).with(:old_transport).
                       and_return(true).once                                      
    flexmock(Tem::Firmware::Uploader).should_receive(:upload_cap).
                                      with(:old_transport).once
    assert_equal true, @updater.update_transport(:old_transport),
                 'Outdated smartcard'

    flexmock(@updater).should_receive(:needs_update?).with(:err_transport).
                       and_return(true).once                                      
    flexmock(Tem::Firmware::Uploader).should_receive(:upload_cap).
        with(:err_transport).once.
        and_raise(Smartcard::Iso::ApduError, {:data => [], :status => 0x6A88})
    assert_equal false, @updater.update_transport(:err_transport),
                 'Flaly smartcard'
  end
  
  def _test_needs_update(version, answer)
    session = Object.new
    if version.has_key? :status
      flexmock(Tem::Session).should_receive(:new).
          and_raise(Smartcard::Iso::ApduError, version).once
    else
      flexmock(Tem::Session).should_receive(:new).with(:transport).
          and_return(session).once
      flexmock(session).should_receive(:fw_version).and_return(version).once
    end
    
    assert_equal answer, @updater.needs_update?(:transport), version.inspect 
  end
  
  def test_needs_update
    fw_version = Tem::Firmware::Uploader.fw_version
    
    [
     [{:major => fw_version[:major] + 1, :minor => 0}, false],
     [{:major => fw_version[:major] - 1, :minor => 256}, true],
     [{:major => fw_version[:major], :minor => 0}, true],
     [{:major => fw_version[:major], :minor => 256}, false],
     [{:major => fw_version[:major], :minor => fw_version[:minor] - 1}, true],
     [{:major => fw_version[:major], :minor => fw_version[:minor]}, false],
     [{:major => fw_version[:major], :minor => fw_version[:minor] + 1}, false],
     [{:data => [], :status => 0x6A88}, true],
    ].each do |test_case|
      _test_needs_update *test_case
    end
  end
end
