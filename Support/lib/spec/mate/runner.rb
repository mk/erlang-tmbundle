require 'eunit_formatter'

module Spec
  module Mate
    class Runner
      def run_files(stdout, options={})
        files = ENV['TM_SELECTED_FILES'].split(" ").map do |path|
          File.expand_path(path[1..-2])
        end
        options.merge!({:files => files})
        run(stdout, options)
      end

      def run_file(stdout, options={})
        options.merge!({:files => [single_file]})
        run(stdout, options)
      end

      def run_focussed(stdout, options={})
        options.merge!({:files => [single_file], :line => ENV['TM_LINE_NUMBER']})
        run(stdout, options)
      end

      def run(stdout, options)
        erl = `which erl`
        erl = "/opt/local/bin/erl"
        erlc = "/opt/local/bin/erlc"
        #argv = options[:files].dup
        #argv << '--format'
        #argv << 'textmate'
        #if options[:line]
        #  argv << '--line'
        #  argv << options[:line]
        #end
        #argv += ENV['TM_RSPEC_OPTS'].split(" ") if ENV['TM_RSPEC_OPTS']
        #Dir.chdir(project_directory) do
        #  ::Spec::Runner::CommandLine.run(::Spec::Runner::OptionParser.parse(argv, STDERR, stdout))
        #end
        formatter = EunitFormatter.new(stdout)
        counter = 1
        Dir.chdir(project_directory) do
          formatter.start(options[:files].size)
          options[:files].each do |file|
            erlang_module = file.match(/test\/(.*)_test.erl/)[1]
            #stdout << "#{erl} -pa ebin -pa ebin/eunit -run #{erlang_module} test -run init stop"
            formatter.add_example_group("Module #{erlang_module}")
            test_output = `#{erl} -pa ebin -pa ebin/eunit -run #{erlang_module} test -run init stop`
            formatter.example_started("#{erlang_module}")
            if /\*failed\*/ =~ test_output
              #stdout << "Failures in #{erlang_module}:\n#{test_output}"
              formatter.example_failed("#{erlang_module}", counter, "#{test_output}")
              counter += 1
            else
              test_output[/1>\s*(.*)\n/]
              formatter.example_passed("#{erlang_module}")
            end
          end
        end
        #Dir.chdir(project_directory) do
        #  ::Spec::Runner::CommandLine.run()
        #end
      end

      protected
      def single_file
        File.expand_path(ENV['TM_FILEPATH'])
      end

      def project_directory
        File.expand_path(ENV['TM_PROJECT_DIRECTORY'])
      end
    end
  end
end
