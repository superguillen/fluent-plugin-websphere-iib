module Fluent
  class TextParser
    class SyslogParserCustom < Parser
      Plugin.register_parser("syslogcustom", self)
      # From existence TextParser pattern
      REGEXP = '^(?<timestamp>[^ ]*\s*[^ ]* [^ ]*) (?<hostname>[^ ]*) (?<identificador>[a-zA-Z-1-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$'
      # From in_syslog default pattern
      REGEXP_WITH_PRI = '^\<(?<priority>[0-9]+)\>(?<timestamp>[^ ]* {1,2}[^ ]* [^ ]*) (?<hostname>[^ ]*) (?<identificador>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$'
      #Expresion regular cuando esta presente el log del IIB
      IIB_REGEXP = '^(?<product_name>[^\(]+)\((?<nodo>[^\(]+)\) \[Thread(?<thread>[^\[]+)\] \(Msg (?<msg>[^\(]+)\) (?<msgid>[^\:]+)\: (?<message>.*)$'

      config_param :time_format, :string, :default => "%b %d %H:%M:%S"
      #Incluye timezone (se agrega a la fecha de entrada)
      config_param :output_time_format, :string, :default => "%Y-%m-%dT%H:%M:%S.%L%z"
      config_param :with_priority, :bool, :default => false
      config_param :keep_time_key, :bool, :default => true
      config_param :ambiente, :string, :default => nil

      def initialize
        super
        @mutex = Mutex.new
      end

      def configure(conf)
        super

        require 'active_support/time'

        @timezone_offset = Time.now.formatted_offset
        @regexp = @with_priority ? Regexp.new(REGEXP_WITH_PRI) : Regexp.new(REGEXP)
        @iib_regexp = Regexp.new(IIB_REGEXP)
        @time_parser = TextParser::TimeParser.new(@time_format)
      end

      def patterns
        {'format' => @regexp, 'time_format' => @time_format, 'subformat' => @iib_regexp}
      end

      def parse(text)
        m = @regexp.match(text)
        #n = @iib_regexp.match(text)
        unless m
          if block_given?
            yield nil, nil
            return
          else
            return nil, nil
          end
        end

        time = nil
        msg = nil
        
        record = {}
	record["eventype"] = "INFO"
        record["severity"] = "LOW"
        record["severity_level"] = 4
	record["hostname"] = Socket.gethostname 
        m.names.each { |name|
          if value = m[name]
            #$log.info ">>>>>>: #{name}"
            case name
            when "priority"
              record['priority'] = value.to_i
            when "message"
                case record["identificador"]
		when "IIB"
                #$log.info "message:  -> #{value}"
                msg = value
                n = @iib_regexp.match(msg)
                n.names.each { |name| 
                  if msg = n[name]
                    #$log.info ">>>>>>: #{name}"
                    record[name] = msg
                  end
                }

                if record.has_key?("nodo")
                   record["integration_node"] = record["nodo"].split(".")[0]
                   record["integration_server"] = record["nodo"].split(".")[1]
                   record.delete("nodo")
                end

		record["producto"] = record["identificador"]
		record["ambiente"] = @ambiente
		record.delete("identificador")
		record["msgshortname"] = record["msgid"]
		record["eventype"] =  record["msgid"][-1]
		case record["eventype"]
		when "E"
		   record["eventype"] = "ERROR"
		   record["severity"] ="HIGH"
		   record["severity_level"] = 5
		when "W"
		   record["eventype"] = "WARNING"
		   record["severity"] = "MEDIUM"
		   record["severity_level"] = 5
		else
		   record["eventype"] = "INFO"
		   record["severity"] = "LOW"
		   record["severity_level"] = 5
		end		
		else
		record[name] = value
		end
            when "timestamp"
              time = @mutex.synchronize { @time_parser.parse(value.gsub(/ +/, ' ')) }
              #Se calcula timestmap adicionando timezone
              timestamp = @mutex.synchronize { DateTime.strptime(value+@timezone_offset,@time_format+'%z').strftime(@output_time_format) }
              #$log.info "timestamp: #{value+@timezone_offset}"
              record[name] = timestamp 
            else
              record[name] = value
            end
          end
        }

        if @estimate_current_event
          time ||= Engine.now
        end

        if block_given?
          yield time, record
        else
          return time, record
        end
      end
    end
  end #textParser
end
