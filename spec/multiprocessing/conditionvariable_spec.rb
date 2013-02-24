require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'timeout'

describe MultiProcessing::ConditionVariable do

  before do
    @cond = MultiProcessing::ConditionVariable.new
  end

  context "being waited by no process" do

    describe "#signal" do
      it "returns false" do
        @cond.signal.should be_false
      end
    end

    describe "#broadcast" do
      it "returns 0" do
        @cond.broadcast.should == 0
      end
    end

  end

  context "being waited by one process" do

    before do
      @pid = fork do
        mutex = MultiProcessing::Mutex.new
        mutex.synchronize do
          @cond.wait(mutex)
        end
      end
      @detached_thread = Process.detach(@pid)
      sleep 0.1
    end

    describe "#signal" do

      it "returns true" do
        @cond.signal.should be_true
      end

      it "makes waiting process restart" do
        @cond.signal
        sleep 0.1
        timeout(1){ @detached_thread.value }.success?.should be_true
      end

    end

    describe "#broadcast" do

      it "returns number of waited processes" do
        @cond.broadcast.should == 1
      end

      it "makes waiting process restart" do
        @cond.broadcast
        sleep 0.1
        timeout(1){ @detached_thread.value }.success?.should be_true
      end

    end

    after do
      begin
        Process.kill(:TERM, @pid)
      rescue Errno::ESRCH
      end
    end

  end

  context "being waited by multiple processes" do

    before do
      @pid1 = fork do
        mutex = MultiProcessing::Mutex.new
        mutex.synchronize do
          @cond.wait(mutex)
        end
      end
      sleep 0.1
      @pid2 = fork do
        mutex = MultiProcessing::Mutex.new
        mutex.synchronize do
          @cond.wait(mutex)
        end
      end
      @detached_thread1 = Process.detach(@pid1)
      @detached_thread2 = Process.detach(@pid2)
      sleep 0.1
    end

    describe "#signal" do

      it "returns true" do
        @cond.signal.should be_true
      end

      it "makes waiting process restart" do
        @cond.signal
        sleep 0.1
        timeout(1){ @detached_thread1.value }.success?.should be_true
        @detached_thread2.join(0.1).should be_nil
      end

    end

    describe "#broadcast" do

      it "returns number of waited process" do
        @cond.broadcast.should == 2
      end

      it "makes waiting process restart" do
        @cond.broadcast
        sleep 0.1
        timeout(1){ @detached_thread1.value }.success?.should be_true
        timeout(1){ @detached_thread2.value }.success?.should be_true
      end

    end

    after do
      begin
        Process.kill(:TERM, @pid1)
      rescue Errno::ESRCH
      end
      begin
        Process.kill(:TERM,@pid2)
      rescue Errno::ESRCH
      end
    end

  end

  describe "#wait" do

    context "called with MultiProcessing::Mutex" do

      before do
        @mutex = MultiProcessing::Mutex.new
        @pid = fork do
          sleep 0.2
          @cond.signal
        end
      end

      context "until signal" do
        it "blocks" do
          @mutex.synchronize do
            proc{timeout(0.1){@cond.wait(@mutex)}}.should raise_error Timeout::Error
          end
        end
      end

      context "after signal" do
        it "restarts" do
          @mutex.synchronize do
            proc{timeout(0.3){@cond.wait(@mutex)}}.should_not raise_error Timeout::Error
          end
        end
      end

      after do
        begin
          Process.kill :KILL, @pid
        rescue Errno::ESRCH
        end
      end

    end

    context "called with object except MultiProcessing::Mutex" do
      it "raises MultiProcessing::ProcessError" do
        proc{@cond.wait(Object.new)}.should raise_error TypeError
      end
    end

    context "called with unlocked Mutex" do

      it "raises MultiProcessing::ProcessError" do
        mutex = MultiProcessing::Mutex.new
        proc{@cond.wait(mutex)}.should raise_error ArgumentError
      end

      it "still works" do
        mutex = MultiProcessing::Mutex.new
        begin
          @cond.wait(mutex)
        rescue ArgumentError
        end
        @cond.signal.should be_false
        # this means that inner variables are in the state that no process are waiting it
      end
      
    end

  end

end



