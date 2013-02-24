require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Semaphore, "initialized with 2" do

  before do
    @semaphore = MultiProcessing::Semaphore.new 2
  end

  describe "#P" do

    context "when resource is remaining" do
      it "return itself" do
        @semaphore.lock.should === @semaphore
      end
    end

    context "when resource is not remaining" do

      before do
        fork do
          @semaphore.P
          @semaphore.P
          sleep 0.03
        end
        sleep 0.01
      end

      it "blocks" do
        proc{ timeout(0.01){ @semaphore.P } }.should raise_error Timeout::Error
      end

    end

  end

  describe "#V" do

    it "#V returns itself" do
      @semaphore.lock
      @semaphore.unlock.should === @semaphore
    end

    context "when a thread is waiting" do

      before do
        @pid = fork do
          @semaphore.P
          @semaphore.P
          @semaphore.P # blocks
        end
        @detached_thread = Process.detach(@pid)
        sleep 0.01
      end

      it "makes the other thread blocked restart" do
        @semaphore.V
        @detached_thread.join(1).should_not be_nil
      end

      after do
        begin
          Process.kill :TERM, @pid
        rescue Errno::ESRCH
        end
      end

    end

  end

  describe "#count" do

    context "resource locked in same thread" do
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

    context "resource locked in another process" do

      before do
        @pid = fork do
          sleep 0.02
          @semaphore.P
          sleep 0.02
          @semaphore.P
          sleep 0.02
          @semaphore.V
        end
        sleep 0.01
      end

      it "returns number of remaining resource" do
        @semaphore.count.should == 2
        sleep 0.02
        @semaphore.count.should == 1
        sleep 0.02
        @semaphore.count.should == 0
        sleep 0.02
        @semaphore.count.should == 1
      end

      after do
        begin
          Process.kill :TERM, @pid
        rescue Errno::ESRCH
        end
      end

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
          sleep 0.02
        end
        sleep 0.01
        @semaphore.try_P.should be_false
        @semaphore.count.should == 0
      end
    end
  end

  describe "#synchronize" do
    it "locks resource and yields and unlocks" do
      tmp = nil
      @semaphore.count.should == 2
      @semaphore.synchronize do
        @semaphore.count.should == 1
        tmp = true
      end
      tmp.should be_true
      @semaphore.count.should == 2
    end
  end

end



