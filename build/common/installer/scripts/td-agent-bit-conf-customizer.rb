#!/usr/local/bin/ruby
require_relative "ConfigParseErrorLogger"

@td_agent_bit_conf_path = "/etc/opt/microsoft/docker-cimprov/td-agent-bit-geneva-logs_tenant1.conf"

@os_type = ENV["OS_TYPE"]
if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  @td_agent_bit_conf_path = "/etc/fluent-bit/fluent-bit.conf"
end

@default_service_interval = "15"
@default_mem_buf_limit = "10"

def is_number?(value)
  true if Integer(value) rescue false
end

def substituteFluentBitPlaceHolders
  begin
    # Replace the fluentbit config file with custom values if present
    puts "config::Starting to substitute the placeholders in td-agent-bit.conf file for log collection"

    interval = ENV["FBIT_SERVICE_FLUSH_INTERVAL"]
    bufferChunkSize = ENV["FBIT_TAIL_BUFFER_CHUNK_SIZE"]
    bufferMaxSize = ENV["FBIT_TAIL_BUFFER_MAX_SIZE"]
    memBufLimit = ENV["FBIT_TAIL_MEM_BUF_LIMIT"]
    ignoreOlder = ENV["FBIT_TAIL_IGNORE_OLDER"]

    serviceInterval = (!interval.nil? && is_number?(interval) && interval.to_i > 0) ? interval : @default_service_interval
    serviceIntervalSetting = "Flush         " + serviceInterval

    tailBufferChunkSize = (!bufferChunkSize.nil? && is_number?(bufferChunkSize) && bufferChunkSize.to_i > 0) ? bufferChunkSize : nil

    tailBufferMaxSize = (!bufferMaxSize.nil? && is_number?(bufferMaxSize) && bufferMaxSize.to_i > 0) ? bufferMaxSize : nil

    if ((!tailBufferChunkSize.nil? && tailBufferMaxSize.nil?) || (!tailBufferChunkSize.nil? && !tailBufferMaxSize.nil? && tailBufferChunkSize.to_i > tailBufferMaxSize.to_i))
      puts "config:warn buffer max size must be greater or equal to chunk size"
      tailBufferMaxSize = tailBufferChunkSize
    end

    tailMemBufLimit = (!memBufLimit.nil? && is_number?(memBufLimit) && memBufLimit.to_i > 10) ? memBufLimit : @default_mem_buf_limit
    tailMemBufLimitSetting = "Mem_Buf_Limit " + tailMemBufLimit + "m"

    text = File.read(@td_agent_bit_conf_path)
    new_contents = text.gsub("${SERVICE_FLUSH_INTERVAL}", serviceIntervalSetting)
    new_contents = new_contents.gsub("${TAIL_MEM_BUF_LIMIT}", tailMemBufLimitSetting)
    if !tailBufferChunkSize.nil?
      new_contents = new_contents.gsub("${TAIL_BUFFER_CHUNK_SIZE}", "Buffer_Chunk_Size " + tailBufferChunkSize + "m")
    else
      new_contents = new_contents.gsub("\n    ${TAIL_BUFFER_CHUNK_SIZE}\n", "\n")
    end
    if !tailBufferMaxSize.nil?
      new_contents = new_contents.gsub("${TAIL_BUFFER_MAX_SIZE}", "Buffer_Max_Size " + tailBufferMaxSize + "m")
    else
      new_contents = new_contents.gsub("\n    ${TAIL_BUFFER_MAX_SIZE}\n", "\n")
    end

    if !ignoreOlder.nil? && !ignoreOlder.empty?
      new_contents = new_contents.gsub("${TAIL_IGNORE_OLDER}", "Ignore_Older " + ignoreOlder)
    else
      new_contents = new_contents.gsub("\n    ${TAIL_IGNORE_OLDER}\n", "\n")
    end

    File.open(@td_agent_bit_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in td-agent-bit.conf file"
  rescue => errorStr
    ConfigParseErrorLogger.logError("td-agent-bit-config-customizer: error while substituting values in td-agent-bit.conf file: #{errorStr}")
  end
end

substituteFluentBitPlaceHolders
