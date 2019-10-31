require "rdoc/ri/driver"
require "tempfile"

module DidYouMean
  module Experimental #:nodoc:
    module ArgumentErrorCorrectable
      # TODO: support ArgumentError#receiver to get fast method signatures.
      TRACE = TracePoint.trace(:raise) do |tp|
        e = tp.raised_exception
        if e.is_a?(ArgumentError) &&
           /wrong number of arguments/.match(e.original_message)
          e.instance_variable_set(:@_receiver, tp.self)
          e.instance_variable_set(:@_method_id, tp.method_id)
        end
      end

      def original_message
        method(:to_s).super_method.call
      end

      def to_s
        msg = super.dup

        corrections = signatures
        if !corrections.empty?
          msg << DidYouMean.formatter.message_for(corrections)
        end

        msg
      rescue
        super
      end

      def signatures
        res = []
        if _receiver && _method_id
          if _method_id == :initialize
            m = "#{_receiver.class}.new"
          else
            m = _receiver.method(_method_id).to_s.gsub(/#<Method: ([^>]+)>/) { $1 }
          end

          Tempfile.open("ri") do |f|
            begin
              $stdout = f
              # TODO: Return string directly.
              RDoc::RI::Driver.new(use_stdout: true, names: [m]).run
            ensure
              $stdout = STDOUT
            end
            f.rewind
            if s = /^-+$(.*)^-+$/m.match(f.read)[1].chomp
              res = s.gsub(/\s*->\s*.*$/, '').split(/\n/)
            end
          end
        end
        return res
      end
    end

    ::ArgumentError.send(:attr_reader, :_receiver, :_method_id)
    ::ArgumentError.prepend ArgumentErrorCorrectable
  end
end
