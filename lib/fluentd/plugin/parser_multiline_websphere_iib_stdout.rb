module Fluent
  class TextParser
     class WebsphereSysout < Parser
          Plugin.register_parser("multiline_websphere_iib", self)

          config_param :time_format, :string, :default =>'%m/%d/%y %H:%M:%S:%L %Z'
          config_param :output_time_format, :string, :default =>'%Y-%m-%dT%H:%M:%S.%L%z'
          config_param :format_firstline, :string, :default =>'/\[\d{1,2}\/\d{1,2}\/\d{2,4} \d{1,2}:\d{1,2}:\d{1,2}:\d{1,3}\s.{3}\]/'
          config_param :format1, :string, :default =>'/\[(?<timestamp>\d{1,2}\/\d{1,2}\/\d{2,4} \d{1,2}:\d{1,2}:\d{1,2}:\d{1,3}\s.{3})\]\s+(?<treadid>\S+)\s+(?<msgshortname>\S+)\s+(?<eventype>\S+)\s+(?<msgid>\S+)\s*(?<message>.*)/'
          config_param :ambiente, :string, :default =>'unknow'
          config_param :producto, :string, :default =>'unknow'
          config_param :tipolog, :string, :default =>'websphere.integration_bus'
          config_param :integration_node, :string, :default =>'unknow'
          config_param :integration_server, :string, :default =>'unknow'

          REGEXP_PMRM0003I = '^.*type=(?<type>.+)\s+detail=(?<detail>.+)\s+elapsed=(?<elapsed>\S+)$'
          FORMAT_MAX_NUM = 20

          def initialize
            super
            @mutex = Mutex.new
            @regexp_pmrm0003i = Regexp.new(REGEXP_PMRM0003I)
          end

          def configure(conf)
            super

            conf["format1"] ||= @format1

            $log.info "format1:  -> "+@format1

            formats = parse_formats(conf).compact.map { |f| f[1..-2] }.join
            $log.info "formats:  -> "+formats
            begin
              @regex = Regexp.new(formats, Regexp::MULTILINE)
              if @regex.named_captures.empty?
                raise "No named captures"
              end
              @parser = RegexpParser.new(@regex, conf)
            rescue => e
              raise ConfigError, "Invalid regexp '#{formats}': #{e}"
            end

            if @format_firstline
              check_format_regexp(@format_firstline, 'format_firstline')
              @firstline_regex = Regexp.new(@format_firstline[1..-2])
            end
          end

          def parse(text, &block)
            m = @regex.match(text)

            unless m
              if block_given?
                yield nil, nil
                return
              else
                return nil, nil
              end
            end

            record = {}
            record["tipolog"] = @tipolog
            record["integration_node"] = @integration_node
            record["integration_server"] = @integration_server
            record["producto"] = @producto
            record["ambiente"] = @ambiente
            record["eventype"] = "INFO"
            record["severity"] = "LOW"
            record["severity_level"] = 5
            record["hostname"] = Socket.gethostname 

            m.names.each { |name|
                if value = m[name]
                  case name
                  when "timestamp"
                    #Se calcula timestmap adicionando timezone
                    timestamp = @mutex.synchronize { DateTime.strptime(value,@time_format).strftime(@output_time_format) }
                    time = @mutex.synchronize { DateTime.strptime(value,@time_format).to_time.to_i }
                    #$log.info "timestamp: #{value+@timezone_offset}"
                    record[name] = timestamp 
                  when "eventype"
                     record[name] = value
                     case record[name]
                     when "I"
                        record["eventype"] = "INFO"
                        record["severity"] = "LOW"
                        record["severity_level"] = 5
                     when "D"
                        record["eventype"] = "DETAIL"
                        record["severity"] = "LOW"
                        record["severity_level"] = 6
                     when "E"
                        record["eventype"] = "ERROR"
                        record["severity"] ="HIGH"
                        record["severity_level"] = 5
                     when "W"
                        record["eventype"] = "WARNING"
                        record["severity"] = "MEDIUM"
                        record["severity_level"] = 5
                     when "F"
                        record["eventype"] = "FATAL"
                        record["severity"] = "HIGH"
                        record["severity_level"] = 4
                     when "C"
                        record["eventype"] = "CONFIGURATION"
                        record["severity"] = "MEDIUM"
                        record["severity_level"] = 5
                     when "O"
                        record["eventype"] = "SYSTEM_OUTPUT"
                        record["severity"] = "LOW"
                        record["severity_level"] = 5
                     when "R"
                        record["eventype"] = "SYSTEM_ERROR"
                        record["severity"] = "LOW"
                        record["severity_level"] = 5
                     when "Z"
                        record["eventype"] = "NOT_RECOGNIZED"
                        record["severity"] = "LOW"
                        record["severity_level"] = 5
                     end

                  when "message"
                     case record["msgid"]
                     when "PMRM0003I:"
                        msg = value
                        #Se extrae datos de request metrics
                        if requestMetrics = @regexp_pmrm0003i.match(msg)
                           record["type"] = requestMetrics["type"]
                           record["detail"] = requestMetrics["detail"]
                           record["elapsed"] = requestMetrics["elapsed"]
                           record["tipolog"] = 'requestmetrics.'+record["tipolog"]
                           record["mesage"].delete
                        end
                     else
                       record[name] = value
                     end
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

          def has_firstline?
            !!@format_firstline
          end

          def firstline?(text)
            @firstline_regex.match(text)
          end

          private

          def parse_formats(conf)
            check_format_range(conf)

            prev_format = nil
            (1..FORMAT_MAX_NUM).map { |i|
              format = conf["format#{i}"]
              if (i > 1) && prev_format.nil? && !format.nil?
                raise ConfigError, "Jump of format index found. format#{i - 1} is missing."
              end
              prev_format = format
              next if format.nil?

              check_format_regexp(format, "format#{i}")
              format
            }
          end

          def check_format_range(conf)
            invalid_formats = conf.keys.select { |k|
              m = k.match(/^format(\d+)$/)
              m ? !((1..FORMAT_MAX_NUM).include?(m[1].to_i)) : false
            }
            unless invalid_formats.empty?
              raise ConfigError, "Invalid formatN found. N should be 1 - #{FORMAT_MAX_NUM}: " + invalid_formats.join(",")
            end
          end

          def check_format_regexp(format, key)
            if format[0] == '/' && format[-1] == '/'
              begin
                Regexp.new(format[1..-2], Regexp::MULTILINE)
              rescue => e
                raise ConfigError, "Invalid regexp in #{key}: #{e}"
              end
            else
              raise ConfigError, "format should be Regexp, need //, in #{key}: '#{format}'"
            end
          end
        end
    end
end
