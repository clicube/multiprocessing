require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'timeout'
require 'thwait'

describe MultiProcessing::ConditionVariable do

  before do
    @cond = MultiProcessing::ConditionVariable.new
  end

  context "being waited by no process" do

    describe "#signal" do
      it "returns false" do
        @cond.signal.should be false
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
      sleep 0.01
    end

    describe "#signal" do

      it "returns true" do
        @cond.signal.should be true
      end

      it "makes waiting process restart" do
        @cond.signal
        Timeout.timeout(1){ @detached_thread.value }.success?.should be true
      end

    end

    describe "#broadcast" do

      it "returns number of waited processes" do
        @cond.broadcast.should == 1
      end

      it "makes waiting process restart" do
        @cond.broadcast
        Timeout.timeout(1){ @detached_thread.value }.success?.should be true
      end

    end

    after do
      begin
        Process.kill(:KILL, @pid)
      rescue Errno::ESRCH
      end
      Process.waitall
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
      @pid2 = fork do
        mutex = MultiProcessing::Mutex.new
        mutex.synchronize do
          @cond.wait(mutex)
        end
      end
      @detached_thread1 = Process.detach(@pid1)
      @detached_thread2 = Process.detach(@pid2)
      sleep 0.01
    end

    describe "#signal" do

      it "returns true" do
        @cond.signal.should be true
      end

      it "makes waiting process restart" do
        @cond.signal
        threads = [@detached_thread1, @detached_thread2]
        thwait = ThreadsWait.new(threads)
        Timeout.timeout(1){ thwait.next_wait.value }.success?.should be true
        thwait.threads[0].should be_alive
      end

    end

    describe "#broadcast" do

      it "returns number of waited process" do
        @cond.broadcast.should == 2
      end

      it "makes waiting process restart" do
        @cond.broadcast
        Timeout.timeout(1){ @detached_thread1.value }.success?.should be true
        Timeout.timeout(1){ @detached_thread2.value }.success?.should be true
      end

    end

    after do
      begin
        Process.kill(:KILL, @pid1)
      rescue Errno::ESRCH
      end
      begin
        Process.kill(:KILL,@pid2)
      rescue Errno::ESRCH
      end
      Process.waitall
    end

  end

  describe "#wait" do

    context "called with MultiProcessing::Mutex" do

      before do
        @mutex = MultiProcessing::Mutex.new
        @pid = fork do
          sleep 0.02
          @cond.signal
        end
      end

      context "until signal" do
        it "blocks" do
          @mutex.synchronize do
            proc{Timeout.timeout(0.01){@cond.wait(@mutex)}}.should raise_error Timeout::Error
          end
        end
      end

      context "after signal" do
        it "restarts" do
          @mutex.synchronize do
            proc{Timeout.timeout(0.03){@cond.wait(@mutex)}}.should_not raise_error
          end
        end
      end

      after do
        begin
          Process.kill :KILL, @pid
        rescue Errno::ESRCH
        end
        Process.waitall
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
        @cond.signal.should be false
        # this means that inner variables are in the state that no process are waiting it
      end

    end

  end

end



