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
    
    DEFAULT_OPTIONS = {
      :java       => 'java'.freeze,
      :args       => nil,
      :java_args  => nil,
      :class_path => nil
    }.freeze
    
    attr_reader :class_or_jar, :options, :stderr
    
    def self.run(*args, &block)
      new(*args).run(&block)
    end
    
    def initialize(class_or_jar, options = {})
      @class_or_jar = class_or_jar
      @options = DEFAULT_OPTIONS.merge(options)
    end
    
    def run
      create_stderr do
        IO.popen(command, IO::RDWR) do |pipe|
          if block_given?
            return yield(pipe, stderr)
          else
            return pipe.read, stderr.read
          end
        end
      end
    end
    
    protected
      def create_stderr
        tempfile = Tempfile.open(TEMPFILE_BASENAME)
        tempfile.close
        File.open(tempfile.path) do |stderr|
          @stderr = stderr
          yield
        end
      end
      
      def command
        command = []
        command << options[:java]
        command << options[:java_args]
        command << "-classpath #{classpath.inspect}" if classpath
        command << class_or_jar
        command << options[:args]
        command << redirect_stderr
        command.compact.join(' ')
      end
      
      def classpath
        return @classpath if defined?(@classpath)
        if (classpath = options[:classpath]) && !classpath.empty?
          classpath = classpath.join(':') if classpath.respond_to?(:join)
          @classpath = classpath
        end
      end
      
      def redirect_stderr
        "2> #{stderr.path.inspect}"
      end
  end
end
