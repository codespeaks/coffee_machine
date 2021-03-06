require File.dirname(__FILE__) + '/../lib/coffee_machine'

begin
  gem 'test-unit'
rescue Gem::LoadError
  puts "Run `gem install test-unit` if encountering the following exception:"
  puts "uninitialized constant Test::Unit::TestResult::TestResultFailureSupport (NameError)".inspect
end if RUBY_PLATFORM =~ /(win|w)32/

require 'test/unit'
require 'mocha'
require 'stringio'
require 'set'

class CoffeeMachineTest < Test::Unit::TestCase
  def test_run_class
    CoffeeMachine::JavaRunner.expects(:run).with('Foo')
    CoffeeMachine.run_class('Foo')
    
    CoffeeMachine::JavaRunner.expects(:run).with('"path/to/Foo.class"')
    CoffeeMachine.run_class('path/to/Foo.class')
  end
  
  def test_run_jar
    CoffeeMachine::JavaRunner.expects(:run).with('-jar "path/to/foo.jar"')
    CoffeeMachine.run_jar('path/to/foo.jar')
  end
  
  def test_run_methods_forward_args
    CoffeeMachine::JavaRunner.expects(:run).with('Foo', '--foo -bar')
    CoffeeMachine.run_class('Foo', '--foo -bar')
    CoffeeMachine::JavaRunner.expects(:run).with('Foo', '--foo -bar', :foo => :bar)
    CoffeeMachine.run_class('Foo', '--foo -bar', :foo => :bar)
  end
  
  def test_program_args_as_string
    should_run_command %{java Foo -bar --baz}
    CoffeeMachine::JavaRunner.run('Foo', '-bar --baz')
  end
  
  def test_program_args_as_hash
    should_run_command do |command|
      if command =~ /^java Foo (.*) 2>/
        $1.scan(/--?\w+(?: \w+)?/).to_set == Set.new(['-bar', '--baz', '--foo 42'])
      end
    end
    CoffeeMachine::JavaRunner.run('Foo', {
      '-bar'  => true,
      '--baz' => true,
      '--foo' => 42
    })
  end
  
  def test_program_args_as_array
    should_run_command %{java Foo -bar --baz --foo 42}
    CoffeeMachine::JavaRunner.run('Foo', ['-bar', '--baz', '--foo 42'])
  end
  
  def test_java_option
    should_run_command %{/path/to/java Foo}
    CoffeeMachine::JavaRunner.run('Foo', :java => '/path/to/java')
  end
  
  def test_java_args_options_as_string
    should_run_command %{java -bar --baz Foo}
    CoffeeMachine::JavaRunner.run('Foo', :java_args => '-bar --baz')
  end
  
  def test_java_args_options_as_hash
    should_run_command do |command|
      if command =~ /^java (.*) Foo/
        $1.scan(/--?\w+(?: \w+)?/).to_set == Set.new(['-bar', '--baz', '--foo 42'])
      end
    end
    CoffeeMachine::JavaRunner.run('Foo', :java_args => {
      '-bar'  => true,
      '--baz' => true,
      '--foo' => 42
    })
  end
  
  def test_classpath_option
    should_run_command %{java -classpath /path/to/foo:bar Foo}
    CoffeeMachine::JavaRunner.run('Foo', :classpath => '/path/to/foo:bar')
    
    should_run_command %{java -classpath "/path/to/foo":"bar"}
    CoffeeMachine::JavaRunner.run('Foo', :classpath => ['/path/to/foo', 'bar'])
  end
  
  def test_block_given
    should_run_command(/^java Foo 2> "(.*)"$/).yields(:a_stream)
    return_value = CoffeeMachine::JavaRunner.run('Foo') do |pipe, stderr|
      assert_equal(:a_stream, pipe)
      assert_respond_to stderr, :read
      assert_equal stderr.path, @match.captures.first
      :value_returned_by_block
    end
    assert_equal :value_returned_by_block, return_value
  end
  
  def test_stdout_return_value
    should_run_command(%{java Foo}).yields(StringIO.new('STDOUT content'))
    stdout_content, stderr_content = CoffeeMachine::JavaRunner.run('Foo')
    assert_equal 'STDOUT content', stdout_content
    assert_equal '', stderr_content
  end
  
  def test_stderr_return_value
    stdout_content, stderr_content = CoffeeMachine::JavaRunner.run('',
      :java => 'ruby',
      :java_args =>  %{-e "STDERR.print('STDERR content')"}
    )
    assert_equal '', stdout_content
    assert_equal 'STDERR content', stderr_content
  end
  
  protected
    def should_run_command(pattern = nil)
      pattern = Regexp.compile("^#{pattern}") unless pattern.nil? || pattern.is_a?(Regexp)
      IO.expects(:popen).with do |command, mode|
        if block_given?
          yield(command)
        else
          @match = pattern.match(command)
        end
      end
    end
end
