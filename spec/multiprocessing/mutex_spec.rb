require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Mutex do

  before do
    @mutex = MultiProcessing::Mutex.new
  end

  describe "#lock" do

    it "returns itself" do
      @mutex.lock.should === @mutex
    end

    context "when locked in same thread" do

      before do
        @mutex.lock
      end

      it "raises ProcessError" do
        proc{ @mutex.lock }.should raise_error MultiProcessing::ProcessError
      end

      after do
        @mutex.unlock
      end

    end

    context "when locked in another thread but same process" do

      before do
        Thread.new do
          @mutex.lock
          sleep 0.3
          @mutex.unlock
        end
        sleep 0.1
      end

      it "blocks" do
        proc{ timeout(0.1){ @mutex.lock } }.should raise_error Timeout::Error
      end

    end

    context "when locked in another process" do

      before do
        fork do
          @mutex.lock
          sleep 0.2
          @mutex.unlock
        end
        sleep 0.1
      end

      it "blocks" do
        proc{ timeout(0.1){ @mutex.lock } }.should raise_error Timeout::Error
      end

    end

  end

  describe "#unlock" do

    context "when locked in same thread" do

      before do
        @mutex.lock
      end

      it "return itself" do
        @mutex.unlock.should === @mutex
      end

      context "when another thread in same process is blocked" do

        before do
          @thread = Thread.new do
            @mutex.lock
            @mutex.unlock
          end
          sleep 0.1
        end

        it "makes the other blocked thread restart" do
          @mutex.unlock
          proc{ timeout(0.1){ @thread.join } }.should_not raise_error Timeout::Error
        end

      end

      context "when another thread in another process is blocked" do

        before do
          @pid = fork do
            @mutex.lock
            @mutex.unlock
          end
          sleep 0.1
        end

        it "makes the other blocked thread restart" do
          @mutex.unlock
          proc{ timeout(0.1){ @thread.join } }.should_not raise_error Timeout::Error
        end

        after do
          begin
            Process.kill :TERM, @pid
          ensure Errno::ESRCH
          end
        end

      end

    end


    context "when locked in another thread but same process" do

      before do
        Thread.new do
          @mutex.lock
          sleep 0.2
          @mutex.unlock
        end
        sleep 0.1
      end

      it "raise ProcessError" do
        proc{ @mutex.unlock }.should raise_error MultiProcessing::ProcessError
      end

      it "is still locked" do
        begin
          @mutex.unlock
        rescue MultiProcessing::ProcessError
        end
        @mutex.should be_locked
      end

    end

    context "when locked in another process" do

      before do
        fork do
          @mutex.lock
          sleep 0.2
          @mutex.unlock
        end
        sleep 0.1
      end

      it "raises ProcessError" do
        proc{ @mutex.unlock }.should raise_error MultiProcessing::ProcessError
      end

      it "is still locked" do
        begin
          @mutex.unlock
        rescue MultiProcessing::ProcessError
        end
        @mutex.should be_locked
      end

    end

    context "when not locked" do
      it "raises ProcessError" do
        proc{ @mutex.unlock }.should raise_error MultiProcessing::ProcessError
      end
    end

  end


  describe "#locked?" do

    context "when not locked" do
      it "returns false" do
        @mutex.locked?.should be_false
      end
    end

    context "when locked" do
      it "returns true" do
        fork{ @mutex.lock }
        sleep 0.1
        @mutex.locked?.should be_true
      end
    end

  end

  describe "#try_lock" do

    context "when not locked" do

      it "returns true" do
        @mutex.try_lock.should be_true
      end

      it "gets locked" do
        fork{ @mutex.try_lock }
        sleep 0.1
        @mutex.should be_locked
      end

    end

    context "when locked" do

      before do
        fork do
          @mutex.lock
          sleep 0.2
        end
        sleep 0.1
      end

      it "returns false" do
        @mutex.try_lock.should be_false
      end

      it "is still locked" do
        @mutex.try_lock
        @mutex.should be_locked
      end

    end
  end

  describe "#synchronoze" do

    it "is locked in processing block" do
      @mutex.synchronize do
        @mutex.should be_locked
      end
    end

    it "is locked in processing block in other process" do
      fork do
        @mutex.synchronize do
          sleep 0.2
        end
      end
      sleep 0.1
      @mutex.should be_locked
    end

    it "is unlocked after block" do
      @mutex.synchronize do
        :nop
      end
      @mutex.should_not be_locked
    end
  end

  describe "#sleep" do
    it "unlocks, sleeps and re-locks"
  end

end

