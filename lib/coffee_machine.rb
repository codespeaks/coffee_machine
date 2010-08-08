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
    
    TEMPFILE_BASENAME = 'coffee_machine'.freeze
    
    DEFAULT_OPTIONS = {
      :java      => 'java'.freeze,
      :java_args => nil,
      :classpath => nil
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
      create_stderr do |stderr|
        @stderr = stderr
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
      
      def create_stderr(&block)
        tempfile = Tempfile.open(TEMPFILE_BASENAME)
        tempfile.close
        File.open(tempfile.path, &block)
      end
      
      def command
        cmd = []
        cmd << options[:java]
        cmd << java_args
        cmd << classpath
        cmd << class_or_jar
        cmd << program_args
        cmd << redirect_stderr
        cmd.compact.join(' ')
      end
      
      def java_args
        format_args(options[:java_args])
      end
      
      def classpath
        if (classpath = options[:classpath]) && !classpath.empty?
          if classpath.is_a?(Enumerable) && !classpath.is_a?(String)
            classpath = classpath.collect { |dir| dir.inspect }.join(':')
          end
          "-classpath #{classpath}"
        end
      end
      
      def program_args
        format_args(@program_args)
      end
      
      def format_args(args)
        case args
        when Hash
          args.inject([]) do |array, (key, value)|
            array << key
            array << value unless value == true
            array
          end.join(' ')
        when String
          args
        when Enumerable
          args.to_a.join(' ')
        end
      end
      
      def redirect_stderr
        "2> #{stderr.path.inspect}"
      end
  end
end
