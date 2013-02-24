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
          sleep 0.03
          @mutex.unlock
        end
        sleep 0.01
      end

      it "blocks" do
        proc{ timeout(0.01){ @mutex.lock } }.should raise_error Timeout::Error
      end

    end

    context "when locked in another process" do

      before do
        fork do
          @mutex.lock
          sleep 0.03
          @mutex.unlock
        end
        sleep 0.01
      end

      it "blocks" do
        proc{ timeout(0.01){ @mutex.lock } }.should raise_error Timeout::Error
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
          sleep 0.01
        end

        it "makes the other blocked thread restart" do
          @mutex.unlock
          @thread.join(0.01).should_not be_nil
        end

      end

      context "when another thread in another process is blocked" do

        before do
          @pid = fork do
            @mutex.lock
            @mutex.unlock
          end
          @detached_thread = Process.detach(@pid)
          sleep 0.01
        end

        it "makes the other blocked thread restart" do
          @mutex.unlock
          timeout(1){ @detached_thread.value }.should be_success
        end

        after do
          begin
            Process.kill :TERM, @pid
          rescue Errno::ESRCH
          end
        end

      end

    end


    context "when locked in another thread but same process" do

      before do
        Thread.new do
          @mutex.lock
          sleep 0.02
          @mutex.unlock
        end
        sleep 0.01
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
        @pid = fork do
          @mutex.lock
          sleep 0.02
          @mutex.unlock
        end
        sleep 0.01
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
        sleep 0.01
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
        sleep 0.01
        @mutex.should be_locked
      end

    end

    context "when locked" do

      before do
        fork do
          @mutex.lock
          sleep 0.02
        end
        sleep 0.01
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

  describe "#synchronize" do

    context "synchronizing in current thread" do

      it "returns a value returned by block" do
        obj = Object.new
        @mutex.synchronize {
          obj
        }.should === obj
      end

      context "processing block" do
        it "is locked" do
          @mutex.synchronize do
            @mutex.should be_locked
          end
        end
      end

      context "after block" do
        it "is unlocked" do
          @mutex.synchronize{ :nop }
          @mutex.should_not be_locked
        end
      end

      context "raised in block" do
        it "raised same error" do
          proc{ @mutex.synchronize{ raise StandardError.new } }.should raise_error StandardError
        end

        it "is unlocked" do
          begin
            @mutex.synchronize{ raise StandardError.new }
          rescue StandardError
          end
          @mutex.should_not be_locked
        end
      end 
    end

    context "synchronizing in other process" do

      context "processing block" do
        it "is locked" do
          fork do
            @mutex.synchronize do
              sleep 0.02
            end
          end
          sleep 0.01
          @mutex.should be_locked
        end
      end

      context "after block" do
        it "is unlocked" do
          fork do
            @mutex.synchronize{ :nop }
          end
          @mutex.should_not be_locked
        end
      end

    end

  end

  describe "#sleep" do

    context "another thread waits the lock" do

      before do
        @pid = fork do
          sleep 0.02
          @mutex.lock
          @mutex.unlock
        end
        @detached_thread = Process.detach(@pid)
        sleep 0.01
      end

      it "unlocks before sleep" do
        @mutex.synchronize do
          @mutex.sleep 0.01
        end
        timeout(1){ @detached_thread.value }.should be_success
      end

      it "re-locks after sleep" do
        @mutex.synchronize do
          @mutex.sleep 0.01
          @mutex.should be_locked
        end
      end

      after do
        begin
          Process.kill :TERM, @pid
        rescue Errno::ESRCH
        end
      end

    end

    context "error occurs in sleep" do
      it "re-locks" do
        @mutex.synchronize do
          begin
            timeout(0.01){ @mutex.sleep }
          rescue Timeout::Error
          end
          @mutex.should be_locked
        end
      end
    end

  end

end

