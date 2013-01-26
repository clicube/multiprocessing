require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 

describe MultiProcessing::Process do

  it "can be created with block" do
    MultiProcessing::Process.new{:nop}.should be_instance_of MultiProcessing::Process
  end

  it "cannot be created without block" do
    proc{ MultiProcessing::Process.new }.should raise_error MultiProcessing::ProcessError
  end

  it "returns pid" do
    MultiProcessing::Process.new{ :nop }.pid.should be_instance_of Fixnum
  end

  it "joins process" do
    p = MultiProcessing::Process.new { :nop }
    p.join.should_not be_nil
  end

  it "joins process with timeout" do
    p = MultiProcessing::Process.new { :nop }
    p.join(1).should_not be_nil
    p = MultiProcessing::Process.new { sleep 1 }
    p.join(0).should be_nil
  end

  it "returns value" do
    p = MultiProcessing::Process.new { :nop }
    p.value.should be_instance_of ::Process::Status
    p = MultiProcessing::Process.new { :nop }
    p.value.success?.should be_true
    p = MultiProcessing::Process.new { exit 1 }
    p.value.success?.should be_false
  end

  it "returns nil when process does not exist" do
    p = MultiProcessing::Process.new { :nop }
    p.join
    p.value.should be_nil
  end

  it "can be kill" do
    p = MultiProcessing::Process.new { sleep 1 }
    p.kill :TERM
    p.join(0).should be_nil
  end

end

