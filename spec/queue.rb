require 'minitest/spec'
require 'minitest/autorun'
require 'timeout'
require_relative '../queue'
require_relative '../process'

describe MultiProcessing::Queue do

  it "can be created" do
    MultiProcessing::Queue.new.must_be_instance_of MultiProcessing::Queue
  end

  it "returns length of queue" do
    queue = MultiProcessing::Queue.new
    queue.length.must_equal 0
    queue.push :a
    sleep 0.1 # wait for enqueue
    queue.length.must_equal 1
    queue.push :b
    sleep 0.1 # wait for enqueue
    queue.length.must_equal 2
    queue.pop
    queue.length.must_equal 1
    queue.pop
    queue.length.must_equal 0
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
    timeout(1) do
      data_list.length.times do
        result << queue.pop
      end
    end
    result.must_equal data_list
  end

  it "can pass large objects across processes" do
    queue1 = MultiProcessing::Queue.new
    queue2 = MultiProcessing::Queue.new
    data = "a" * 1024 * 1024 * 16 # 16MB
    timeout_sec = 10
    # process to echo queue1 -> queue 2
    process = MultiProcessing::Process.new do
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
    timeout(timeout_sec) do
      queue1.push data
      result = queue2.pop
    end
    process.kill :TERM
    result.must_equal data
  end

  it "can pass as many as objects across processes" do
    queue1 = MultiProcessing::Queue.new
    queue2 = MultiProcessing::Queue.new
    data_list = Array.new(1000){|i| "a"*1000 }
    timeout_sec = 10
    # process to echo queue1 -> queue 2
    process = MultiProcessing::Process.new do
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
    timeout(timeout_sec) do
      Thread.new do
        data_list.each do |data|
          queue1.push data
        end
      end
      data_list.length.times do
        result << queue2.pop
      end
    end
    process.kill :TERM
    result.must_equal data_list
  end

  it "can be closed and joined enqueue thread before enqueue" do
    queue = MultiProcessing::Queue.new
    thread = Thread.new { queue.close.join_thread }
    thread.join.must_be :!=, nil
  end

  it "can be closed and joined enqueue thread after enqueue" do
    queue = MultiProcessing::Queue.new
    data_list = Array.new(1000){|i| "a"*1000 }
    timeout_sec = 10
    process = MultiProcessing::Process.new do
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
    th.join(timeout_sec).must_be :!=, nil
    process.kill(:TERM)
  end

  it "cannot be joined before being closed" do
    queue = MultiProcessing::Queue.new
    proc{ queue.join_thread }.must_raise(MultiProcessing::QueueError)
  end


end


