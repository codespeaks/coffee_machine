module CoffeeMachine
  extend self
  
  def run_class(java_class, options = {}, &block)
    java_class = java_class.inspect if java_class =~ /\.class$/
    JavaRunner.run(java_class, options, &block)
  end
  
  def run_jar(path_to_jar, options = {}, &block)
    JavaRunner.run("-jar #{path_to_jar.inspect}", options, &block)
  end
  
  class JavaRunner # :nodoc:
    autoload :Tempfile, 'tempfile'
    
    TEMPFILE_BASENAME = 'ruby-java'.freeze
    DEFAULT_JAVA = 'java'.freeze
    
    attr_reader :class_or_jar, :options, :stderr
    
    def self.run(*args, &block)
      new(*args).run(&block)
    end
    
    def initialize(class_or_jar, options = {})
      @class_or_jar = class_or_jar
      @options = options
    end
    
    def run
      create_stderr_tempfile do
        IO.popen(command, IO::RDWR) do |stream|
          if block_given?
            return yield(stream, stderr)
          else
            return stream.read, stderr.read
          end
        end
      end
    end
    
    protected
      def create_stderr_tempfile
        tempfile = Tempfile.open(TEMPFILE_BASENAME)
        tempfile.close
        File.open(tempfile.path) do |stderr|
          @stderr = stderr
          yield
        end
      end
      
      def command
        command = []
        command << java
        command << options[:java_args] if options[:java_args]
        command << "-classpath #{classpath.inspect}" if classpath
        command << class_or_jar
        command << options[:args] if options[:args]
        command << "2>" << stderr.path.inspect
        command.join(' ')
      end
      
      def java
        options[:java] || DEFAULT_JAVA
      end
      
      def classpath
        return @classpath if defined?(@classpath)
        if (classpath = options[:classpath]) && !classpath.empty?
          classpath = classpath.join(':') if classpath.respond_to?(:join)
          @classpath = classpath
        end
      end
  end
end
