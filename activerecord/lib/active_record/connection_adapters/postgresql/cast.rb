module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Cast
        def point_to_string(point) # :nodoc:
          "(#{point[0]},#{point[1]})"
        end

        def string_to_point(string) # :nodoc:
          if string[0] == '(' && string[-1] == ')'
            string = string[1...-1]
          end
          string.split(',').map{ |v| Float(v) }
        end

        def string_to_time(string) # :nodoc:
          return string unless String === string

          case string
          when 'infinity'; Float::INFINITY
          when '-infinity'; -Float::INFINITY
          when / BC$/
            super("-" + string.sub(/ BC$/, ""))
          else
            super
          end
        end

        def string_to_bit(value) # :nodoc:
          case value
          when /^0x/i
            value[2..-1].hex.to_s(2) # Hexadecimal notation
          else
            value                    # Bit-string notation
          end
        end

        def hstore_to_string(object, array_member = false) # :nodoc:
          if Hash === object
            string = object.map { |k, v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(',')
            string = escape_hstore(string) if array_member
            string
          else
            object
          end
        end

        def string_to_hstore(string) # :nodoc:
          if string.nil?
            nil
          elsif String === string
            Hash[string.scan(HstorePair).map { |k, v|
              v = v.upcase == 'NULL' ? nil : v.gsub(/\A"(.*)"\Z/m,'\1').gsub(/\\(.)/, '\1')
              k = k.gsub(/\A"(.*)"\Z/m,'\1').gsub(/\\(.)/, '\1')
              [k, v]
            }]
          else
            string
          end
        end

        def json_to_string(object) # :nodoc:
          if Hash === object || Array === object
            ActiveSupport::JSON.encode(object)
          else
            object
          end
        end

        def array_to_string(value, column, adapter) # :nodoc:
          casted_values = value.map do |val|
            if String === val
              if val == "NULL"
                "\"#{val}\""
              else
                quote_and_escape(adapter.type_cast(val, column, true))
              end
            else
              adapter.type_cast(val, column, true)
            end
          end
          "{#{casted_values.join(',')}}"
        end

        def range_to_string(object) # :nodoc:
          from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
          to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
          "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
        end

        def string_to_json(string) # :nodoc:
          if String === string
            ActiveSupport::JSON.decode(string)
          else
            string
          end
        end

        def string_to_cidr(string) # :nodoc:
          if string.nil?
            nil
          elsif String === string
            begin
              IPAddr.new(string)
            rescue ArgumentError
              nil
            end
          else
            string
          end
        end

        def cidr_to_string(object) # :nodoc:
          if IPAddr === object
            "#{object.to_s}/#{object.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
          else
            object
          end
        end

        def string_to_array(string, oid) # :nodoc:
          parse_pg_array(string).map {|val| type_cast_array(oid, val)}
        end

        private

          HstorePair = begin
            quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
            unquoted_string = /(?:\\.|[^\s,])[^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
            /(#{quoted_string}|#{unquoted_string})\s*=>\s*(#{quoted_string}|#{unquoted_string})/
          end

          def escape_hstore(value)
            if value.nil?
              'NULL'
            else
              if value == ""
                '""'
              else
                '"%s"' % value.to_s.gsub(/(["\\])/, '\\\\\1')
              end
            end
          end

          ARRAY_ESCAPE = "\\" * 2 * 2 # escape the backslash twice for PG arrays

          def quote_and_escape(value)
            case value
            when "NULL", Numeric
              value
            else
              value = value.gsub(/\\/, ARRAY_ESCAPE)
              value.gsub!(/"/,"\\\"")
              "\"#{value}\""
            end
          end

          def type_cast_array(oid, value)
            if ::Array === value
              value.map {|item| type_cast_array(oid, item)}
            else
              oid.type_cast value
            end
          end
      end
    end
  end
end
