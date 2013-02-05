require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Semaphore, "initialized with 1" do

  before do
    @semaphore = MultiProcessing::Semaphore.new 1
  end

  it "#P return itself" do
    @semaphore.lock.should === @semaphore
  end

  it "#V returns itself" do
    @semaphore.lock
    @semaphore.unlock.should === @semaphore
  end


  it "#count returns number of remaining resource" do
    @semaphore.count.should == 1
    @semaphore.P
    @semaphore.count.should == 0
    @semaphore.V
    @semaphore.V
    @semaphore.count.should == 2
  end

  it "#try_P returns true if succeed, and P correctly" do
    @semaphore.try_P.should be_true
    @semaphore.count.should == 0
  end

  it "#try_P returns false if failed" do
    process = MultiProcessing::Process.new do
      @semaphore.P
      sleep 0.2
    end
    sleep 0.1
    @semaphore.try_P.should be_false
  end

  it "#synchronize can lock resource and yield and free" do
    tmp = nil
    @semaphore.synchronize do
      @semaphore.count.should == 0
      tmp = true
    end
    tmp.should be_true
    @semaphore.count.should == 1
  end
  


end

