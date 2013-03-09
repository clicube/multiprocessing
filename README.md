# MultiProcessing #

MultiProcessing provides classes for
inter-process synchronization and communication in Ruby.

These classes can be used like ones in Ruby standard library for multi threading.

To realize communicating across processes,
MultiProcessing uses pipes (IO.pipe).
You have to use #fork to create process which accesses synchonizing/communication object.
For this reason, MultiProcessing can be used only on Unix or Linux.

## Install ##

    gem install multiprocessing

## Provided Classes ##

* Mutex
* ConditionVariable
* Semaphore
* Queue
* (ExternalObject: under development)

In addition, IO.name\_pipe is added.

## Mutex ##

Process version of Mutex.
It can be used like ::Mutex in Ruby standard library.

Example:

    require 'multiprocessing'
    
    mutex = MultiProcessing::Mutex.new
    3.times do
      fork do
        mutex.synchronize do
          # critical section
          puts Process.pid
          sleep 1
        end
      end
    end
    Process.waitall
    # => prints 3 pids of forked process in 1 sec interval

Note: Do not fork in critical section.

## ConditionVariable ##

Process version of ConditionVariable.
It can be used like ::ConditionVariable in Ruby standard library.

Example:

    require 'multiprocessing'
    
    m = MultiProcessing::Mutex.new
    cond = MultiProcessing::ConditionVariable.new
    3.times do
      fork do
        m.synchronize do
          puts "waiting pid:#{Process.pid}"
          cond.wait(m)
          puts "restarted pid:#{Process.pid}"
        end
      end
    end
    sleep 0.1      # => 3 processes get waiting a signal
    cond.signal    # => One process restarts
    cond.broadcast # => Remaining 2 process restart
    Process.waitall


## Semaphore ##

Semaphore is like Mutex but it can manage multiple resources.
It is initialized with initiali number of resources.
It can be release from the thread or process which didn't lock the semaphore.

Example:

    require 'multiprocessing'
    
    s = MultiProcessing::Semaphore.new 2
    3.times do
      fork do
        s.synchronize do
          puts "pid: #{Process.pid}"
          sleep 1
        end
      end
    end
    Process.waitall
    # => two processes prints its pid immediately
    #    but the other does late.

## Queue ##

Process version of Queue.
It provides away to communication between processes.
It can be used like ::Queue in Ruby standard library.

Queue usees pipes to communicate with other processes.
Queue#push} starts background thread ti write data to the pipe.
Avoiding to exit process before writing to the pipe,
use Queue#close and Queue#join\_thread.
Queue#join\_thread waits until all data is written to the pipe.

Example:

    require 'multiprocessing'
     
    q = MultiProcessing::Queue.new
    fork do
      q.push :nyan
      q.push :wan
      q.close.join_thread
    end
    q.pop # => :nyan
    q.pop # => :wan

