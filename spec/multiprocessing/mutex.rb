require 'minitest/spec'
require 'minitest/autorun'
require 'timeout'
require_relative '../../lib/multiprocessing/mutex'
require_relative '../../lib/multiprocessing/process'

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

  it "raises ProcessError when being unlocked if not locked" do
    proc{ @mutex.unlock }.must_raise MultiProcessing::ProcessError
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

  it "raise ProcessError and does not unlock when unlocking by other processes" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      sleep 0.2
      @mutex.unlock
    end
    sleep 0.1
    proc{ @mutex.unlock }.must_raise MultiProcessing::ProcessError
    process.value.success?.must_equal true
  end

  it "returns true when try_lock succeed, and lock correctly" do
    @mutex.try_lock.must_equal true
    @mutex.locked?.must_equal true
    @mutex.unlock.must_be_same_as @mutex
  end

  it "returns false when try_lock failed" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      sleep 0.2
    end
    sleep 0.1
    @mutex.try_lock.must_equal false
  end

  it "s sleep method unlocks and sleeps and re-locks itself" do
    process = MultiProcessing::Process.new do
      @mutex.lock
      @mutex.sleep(0.2)
      sleep 0.2
      @mutex.unlock
    end
    sleep 0.1
    @mutex.try_lock.must_equal true
    @mutex.unlock
    sleep 0.2
    @mutex.try_lock.must_equal false
    timeout(1){ process.value }.success?.must_equal true
  end


end

