require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
require 'timeout'

describe MultiProcessing::Queue do

  before do
    @queue = MultiProcessing::Queue.new
  end

  describe "#enq" do

    context "passed a normal object" do
      it "returns itself" do
        retval = @queue.enq :nyan
        retval.should === @queue
      end
    end

    context "passed an un-serializable object" do
      it "raises TypeError/ArgumentError" do
        proc{ @queue.enq proc{} }.should raise_error TypeError
      end
    end

    context "already closed" do
      it "raises QueueError" do
        @queue.close
        proc{ @queue.enq :nyan } .should raise_error MultiProcessing::QueueError
      end
    end

  end

  describe "#deq" do

    before do
      @data_set = [ 123, 3.14, "neko", [1,2,3], {:cat=>"nyan", :dog=>"wan"},"あ" ,"é", "\xC3" ]
    end

    context "enqueued from same process" do
      it "returns correct object" do
        @data_set.each do |data|
          @queue.enq data
          @queue.deq.should == data
        end
      end
    end

    context "enqueued from another process" do
      it "returns correct object" do
        pid = fork do
          @data_set.each do |data|
            @queue.enq data
          end
          sleep 1
        end

        ret = []
        @data_set.length.times do
          ret << @queue.deq
        end
        ret.should == @data_set
        begin
          Process.kill :KILL, pid
        rescue Errno::ESRCH
        end
        Process.waitall
      end
    end

    context "nob-block mode" do

      context "the queue holds no item" do
        it "raises QueueError" do
          proc{ @queue.deq(true) }.should raise_error MultiProcessing::QueueError
        end
      end

      context "the queue holds items" do
        it "returns correct object" do
          pid = fork do
            @queue.enq :data
            sleep 1
          end
          sleep 0.05

          ret = @queue.deq(true)
          ret.should == :data

          begin
            Process.kill :KILL, pid
          rescue Errno::ESRCH
          end
          Process.waitall
        end
      end

    end


  end

  describe "#close" do
    it "returns itself" do
      @queue.close.should === @queue
    end
  end

  describe "#join_thread" do

    context "before close" do
      it "raises QueueError" do
        proc{@queue.join_thread}.should raise_error MultiProcessing::QueueError
      end
    end

    context "after close" do

      context "data have never enqueued" do
        it "returns immediatelyl" do
          @queue.close
          proc{Timeout.timeout(0.1){ @queue.join_thread }}.should_not raise_error
        end
      end

      context "data had been enqueued" do

        it "joins enque thread" do
          data = "a" * 1024*65 # > pipe capacity(64K)
          @queue.enq data
          @queue.close
          proc{Timeout.timeout(0.1){ @queue.join_thread }}.should raise_error Timeout::Error
          @queue.deq
          proc{Timeout.timeout(0.1){ @queue.join_thread }}.should_not raise_error
        end

      end
    end
  end

  describe "#length" do
    it "returns a number of items" do
      @queue.length.should == 0
      @queue.enq :a
      @queue.length.should == 1
      @queue.enq :a
      @queue.length.should == 2
      @queue.deq
      @queue.length.should == 1
      @queue.deq
      @queue.length.should == 0
    end
  end

  describe "#empty?" do

    context "the queue holds no item" do
      it "returns true" do
        @queue.should be_empty
      end
    end

    context "the queue has item(s)" do
      it "returns false" do
        @queue.enq :a
        @queue.should_not be_empty
      end
    end

  end

  describe "#clear" do

    context "the queue holds no item" do
      it "do nothing and returns itself" do
        ret = @queue.clear
        @queue.length.should == 0
        ret.should === @queue
      end
    end

    context "the queue holds items" do
      it "clears its items and returns itself" do
        @queue.enq :a
        @queue.enq :a
        ret = @queue.clear
        @queue.length.should == 0
        ret.should === @queue
      end
    end

  end

  context "heavy load given" do

    before do

      @queue1 = @queue
      @queue2 = MultiProcessing::Queue.new
      # process to echo queue1 -> queue 2
      @pid = fork do
        echo_queue = ::Queue.new
        Thread.new do
          loop do
            echo_queue.push  @queue1.pop
          end
        end
        Thread.new do
          loop do
            @queue2.push echo_queue.pop
          end
        end
        sleep
      end

    end

    context "many data given" do
      it "throughs correct data" do
        data = Array.new(1000){"a"*100} # 100byte * 1000
        data.each do |item|
          @queue1.enq item
        end
        res = []
        data.length.times do
          res << @queue2.deq
        end
        res.should == data
      end
    end

    context "long data given" do
      it "throughs correct data" do
        data = "a" * 1024 * 1024 # 1 MB
        @queue1.enq data
        res = @queue2.deq
        res.should == data
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

end
__END__
describe "#length" do

  it "returns its length" do
    queue = MultiProcessing::Queue.new
    queue.length.should == 0
    queue.push :a
    sleep 0.1 # wait for enqueue
    queue.length.should == 1
    queue.push :b
    sleep 0.1 # wait for enqueue
    queue.length.should == 2
    queue.pop
    queue.length.should == 1
    queue.pop
    queue.length.should == 0
  end
end

it "can pass object across processes" do
  queue = MultiProcessing::Queue.new
  data_list = [:nyan, [:cat, :dog]]
  fork do
    data_list.each do |data|
      queue.push data
    end  
    sleep 0.1
  end
  result = []
  Timeout.timeout(1) do
    data_list.length.times do
      result << queue.pop
    end
  end
  result.should == data_list
end

it "can pass large objects across processes" do
  queue1 = MultiProcessing::Queue.new
  queue2 = MultiProcessing::Queue.new
  data = "a" * 1024 * 1024 * 16 # 16MB
  timeout_sec = 10
  # process to echo queue1 -> queue 2
  pid = fork do
    echo_queue = ::Queue.new
    Thread.new do
      loop do
        echo_queue.push  queue1.pop
      end
    end
    Thread.new do
      loop do
        queue2.push echo_queue.pop
      end
    end
    sleep timeout_sec + 1
  end
  result = nil
  Timeout.timeout(timeout_sec) do
    queue1.push data
    result = queue2.pop
  end
  Process.kill :KILL,pid
  Process.waitall
  result.should == data
end

it "can pass as many as objects across processes" do
  queue1 = MultiProcessing::Queue.new
  queue2 = MultiProcessing::Queue.new
  data_list = Array.new(1000){|i| "a"*1000 }
  timeout_sec = 10
  # process to echo queue1 -> queue 2
  pid = fork do
    echo_queue = ::Queue.new
    Thread.new do
      loop do
        echo_queue.push  queue1.pop
      end
    end
    Thread.new do
      loop do
        queue2.push echo_queue.pop
      end
    end
    sleep timeout_sec + 1
  end
  result = []
  Timeout.timeout(timeout_sec) do
    Thread.new do
      data_list.each do |data|
        queue1.push data
      end
    end
    data_list.length.times do
      result << queue2.pop
    end
  end
  Process.kill :KILL,pid
  Process.waitall
  result.should == data_list
end

it "can be closed and joined enqueue thread before enqueue" do
  queue = MultiProcessing::Queue.new
  thread = Thread.new { queue.close.join_thread }
  thread.join.should_not be_nil
end

it "can be closed and joined enqueue thread after enqueue" do
  queue = MultiProcessing::Queue.new
  data_list = Array.new(1000){|i| "a"*1000 }
  timeout_sec = 10
  pid = fork do
    data_list.length.times do
      queue.pop
    end
    sleep timeout_sec + 1
  end
  th = Thread.new do
    data_list.each do |data|
      queue.push data
    end
    queue.close.join_thread
  end
  th.join(timeout_sec).should_not be_nil
  Process.kill :KILL,pid
  Process.waitall
end

it "cannot be joined before being closed" do
  queue = MultiProcessing::Queue.new
  proc{ queue.join_thread }.should raise_error MultiProcessing::QueueError
end

  end


