require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Semaphore, "initialized with 2" do

  before do
    @semaphore = MultiProcessing::Semaphore.new 2
  end

  describe "#P" do
    it "return itself" do
      @semaphore.lock.should === @semaphore
    end
  end

  describe "#V" do
    it "#V returns itself" do
      @semaphore.lock
      @semaphore.unlock.should === @semaphore
    end
  end

  describe "#count" do
    it "returns number of remaining resource" do
      @semaphore.count.should == 2
      @semaphore.P
      @semaphore.count.should == 1
      @semaphore.P
      @semaphore.count.should == 0
      @semaphore.V
      @semaphore.count.should == 1
    end
  end

  describe "#try_P" do

    context "when remaining resource" do
      it "returns true" do
        @semaphore.try_P.should be_true
        @semaphore.count.should == 1
      end
    end

    context "when not remaining resource" do
      it "returns false" do
        pid = fork do
          @semaphore.P
          @semaphore.P
          sleep 0.2
        end
        sleep 0.1
        @semaphore.try_P.should be_false
        @semaphore.count.should == 0
      end
    end
  end

  describe "#synchronize" do
    it "#synchronize can lock resource and yield and free" do
      tmp = nil
      @semaphore.synchronize do
        @semaphore.count.should == 1
        tmp = true
      end
      tmp.should be_true
      @semaphore.count.should == 2
    end
  end

end



