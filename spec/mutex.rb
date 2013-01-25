require 'minitest/spec'
require 'minitest/autorun'
require 'timeout'
require_relative '../mutex'
require_relative '../process'

describe MultiProcessing::Mutex do

  before do
    @mutex = MultiProcessing::Mutex.new
  end

  it "can be newed without argument" do
    @mutex.must_be_instance_of MultiProcessing::Mutex
  end

  it "returns itself when being locked" do
    @mutex.lock.must_be_same_as @mutex
  end

  it "returns itself when being unlocked if locked" do
    @mutex.lock
    @mutex.unlock.must_be_same_as @mutex
  end

  it "returns nil when being unlocked if not locked" do
    @mutex.unlock.must_be_nil
  end

  it "s locked? returns false if not locked" do
    @mutex.locked?.must_equal false
  end

  it "s locked? returns true if locked" do
    @mutex.lock
    @mutex.locked?.must_equal true
  end

  it "locks/unlocks other process" do
    process = MultiProcessing::Process.new do
      sleep 0.1
      @mutex.lock
      @mutex.unlock
    end
    @mutex.lock
    sleep 0.2
    process.join(0).must_be_nil
    @mutex.unlock
    timeout(1){ process.join; true }.must_equal true
  end

  it "can synchronize with other process" do
    process = MultiProcessing::Process.new do
      sleep 0.1
      @mutex.synchronize do
        :nop
      end
    end
    @mutex.synchronize do
      sleep 0.2
      process.join(0).must_be_nil
    end
    timeout(1){ process.join; true }.must_equal true
  end

  it "cannot lock twice" do
    proc{
      @mutex.lock
      @mutex.lock
    }.must_raise MultiProcessing::ProcessError
  end

  it "returns nil and does not unlock when being unlocked in other processes" do
    @mutex.lock
    process = MultiProcessing::Process.new do
      if @mutex.unlock == nil
        exit 0
      else
        exit 1
      end
    end
    process.value.success?.must_equal true
    @mutex.unlock.must_be_same_as @mutex
  end

  it "returns true when try_lock succeed" do
    @mutex.try_lock.must_equal true
    @mutex.locked?.must_equal true
  end

  it "returns false when try_lock failed" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      sleep 0.2
    end
    sleep 0.1
    @mutex.try_lock.must_equal false
  end

  it "sleeps and restore lock status" do
    @mutex.sleep(0)
    @mutex.locked?.must_equal false
    @mutex.lock
    @mutex.sleep(0)
    @mutex.locked?.must_equal true
  end

end

