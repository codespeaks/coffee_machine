module CoffeeMachine
  extend self
  
  def run_class(java_class, *args, &block)
    java_class = java_class.inspect if java_class =~ /\.class$/
    JavaRunner.run(java_class, *args, &block)
  end
  
  def run_jar(path_to_jar, *args, &block)
    JavaRunner.run("-jar #{path_to_jar.inspect}", *args, &block)
  end
  
  class JavaRunner # :nodoc:
    autoload :Tempfile, 'tempfile'
    
    TEMPFILE_BASENAME = 'ruby-java'.freeze
    
    DEFAULT_OPTIONS = {
      :java       => 'java'.freeze,
      :java_args  => nil,
      :class_path => nil
    }.freeze
    
    attr_reader :class_or_jar, :options, :stderr
    
    def self.run(*args, &block)
      new(*args).run(&block)
    end
    
    def initialize(class_or_jar, program_args = nil, options = {})
      @class_or_jar = class_or_jar
      options, program_args = program_args, nil if options?(program_args)
      @program_args, @options = program_args, DEFAULT_OPTIONS.merge(options)
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
      def options?(arg)
        arg.is_a?(Hash) && arg.keys.any? { |k| k.is_a?(Symbol) }
      end
      
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
        command << java_args
        command << "-classpath #{classpath.inspect}" if classpath
        command << class_or_jar
        command << program_args
        command << redirect_stderr
        command.compact.join(' ')
      end
      
      def java_args
        format_args(options[:java_args])
      end
      
      def classpath
        return @classpath if defined?(@classpath)
        if (classpath = options[:classpath]) && !classpath.empty?
          classpath = classpath.join(':') if classpath.respond_to?(:join)
          @classpath = classpath
        end
      end
      
      def program_args
        format_args(@program_args)
      end
      
      def format_args(args)
        case args
        when Hash
          args = (args.to_a.flatten - [true]).join(' ')
        when Enumerable
          args = args.to_a.join(' ')
        end
      end
      
      def redirect_stderr
        "2> #{stderr.path.inspect}"
      end
  end
end
