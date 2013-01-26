require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Mutex do

  before do
    @mutex = MultiProcessing::Mutex.new
  end

  it "#lock returns itself" do
    @mutex.lock.should === @mutex
  end

  it "#unlock returns itself if locked" do
    @mutex.lock
    @mutex.unlock.should === @mutex
  end

  it "#unlock raises ProcessError if not locked" do
    proc{ @mutex.unlock }.should raise_error MultiProcessing::ProcessError
  end

  it "#locked? returns false if not locked" do
    @mutex.locked?.should be_false
  end

  it "#locked? returns true if locked" do
    @mutex.lock
    @mutex.locked?.should be_true
  end

  it "#lock, #unlock can locks/unlocks other process" do
    process = MultiProcessing::Process.new do
      sleep 0.1
      @mutex.lock
      @mutex.unlock
    end
    @mutex.lock
    sleep 0.2
    process.join(0).should be_nil
    @mutex.unlock
    proc{ timeout(1){ process.join } }.should_not raise_error Timeout::Error
  end

  it "#synchronize can synchronize with other process" do
    process = MultiProcessing::Process.new do
      sleep 0.1
      @mutex.synchronize do
        :nop
      end
    end
    @mutex.synchronize do
      sleep 0.2
      process.join(0).should be_nil
    end
    proc{ timeout(1){ process.join } }.should_not raise_error Timeout::Error
  end

  it "#lock cannot lock twice" do
    @mutex.lock
    proc{
      @mutex.lock
    }.should raise_error MultiProcessing::ProcessError
  end

  it "#unlock raises ProcessError and does not unlock when unlocking by other processes" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      sleep 0.2
      @mutex.unlock
    end
    sleep 0.1
    proc{ @mutex.unlock }.should raise_error MultiProcessing::ProcessError
    process.value.success?.should be_true
  end

  it "#try_lock returns true if succeed, and lock correctly" do
    @mutex.try_lock.should be_true
    @mutex.locked?.should be_true
    @mutex.unlock.should === @mutex
  end

  it "#try_lock returns false if failed" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      sleep 0.2
    end
    sleep 0.1
    @mutex.try_lock.should be_false
  end

  it "s sleep method unlocks and sleeps and re-locks itself" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      @mutex.sleep(0.2)
      sleep 0.2
      @mutex.unlock
    end
    sleep 0.1
    @mutex.try_lock.should be_true
    @mutex.unlock
    sleep 0.2
    @mutex.try_lock.should be_false
    timeout(1){ process.value }.success?.should be_true
  end


end

