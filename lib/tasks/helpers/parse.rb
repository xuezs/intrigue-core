module Intrigue
module Task
module Parse

  def parse_web_account_from_uri(url)
    # Handle Twitter search results
    if url =~ /https?:\/\/twitter.com\/.*$/
      account_name = url.split("/")[3]
      _create_entity("WebAccount", {
        "domain" => "twitter.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "full"
      })

    # Handle Facebook public profile  results
    elsif url =~ /https?:\/\/www.facebook.com\/(public|pages)\/.*$/
      account_name = url.split("/")[4]
      _create_entity("WebAccount", {
        "domain" => "facebook.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "public"
      })

    # Handle Facebook search results
    elsif url =~ /https?:\/\/www.facebook.com\/.*$/
      account_name = url.split("/")[3]
      _create_entity("WebAccount", {
        "domain" => "facebook.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "full"
      })

    # Handle LinkedIn public profiles
    elsif url =~ /^https?:\/\/www.linkedin.com\/in\/pub\/.*$/
        account_name = url.split("/")[5]
        _create_entity("WebAccount", {
          "domain" => "linkedin.com",
          "name" => account_name,
          "uri" => "#{url}",
          "type" => "public"
        })

    # Handle LinkedIn public directory search results
    elsif url =~ /^https?:\/\/www.linkedin.com\/pub\/dir\/.*$/
      account_name = "#{url.split("/")[5]} #{url.split("/")[6]}"
      _create_entity("WebAccount", {
        "domain" => "linkedin.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "public"
      })

    # Handle LinkedIn world-wide directory results
    elsif url =~ /^http:\/\/[\w]*.linkedin.com\/pub\/.*$/

    # Parses these URIs:
    #  - http://za.linkedin.com/pub/some-one/36/57b/514
    #  - http://uk.linkedin.com/pub/some-one/78/8b/151

      account_name = url.split("/")[4]
      _create_entity("WebAccount", {
        "domain" => "linkedin.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "public" })

    # Handle LinkedIn profile search results
    elsif url =~ /^https?:\/\/www.linkedin.com\/in\/.*$/
      account_name = url.split("/")[4]
      _create_entity("WebAccount", {
        "domain" => "linkedin.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "public" })

    # Handle Google Plus search results
    elsif url =~ /https?:\/\/plus.google.com\/.*$/
      account_name = url.split("/")[3]
      _create_entity("WebAccount", {
        "domain" => "google.com",
        "name" => account_name,
        "uri" => "#{url}",
        "type" => "full" })

    # Handle Hackerone search results
    elsif url =~ /https?:\/\/hackerone.com\/.*$/
      account_name = url.split("/")[3]
      _create_entity("WebAccount", {
        "domain" => "hackerone.com",
        "name" => account_name,
        "uri" => url,
        "type" => "full" }) unless account_name == "reports"
    end
  end


  ###
  ### Entity Parsing
  ###
  def parse_entities_from_content(source_uri, content)
    parse_email_addresses_from_content(source_uri, content)
    parse_dns_records_from_content(source_uri, content)
    parse_phone_numbers_from_content(source_uri, content)
    #parse_uris_from_content(source_uri, content)
  end

  def parse_email_addresses_from_content(source_uri, content)

    @task_result.logger.log "Parsing text from #{source_uri}" if @task_result

    # Make sure we have something to parse
    unless content
      @task_result.logger.log_error "No content to parse, returning" if @task_result
      return nil
    end

    # Scan for email addresses
    addrs = content.scan(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,8}/)
    addrs.each do |addr|
      x = _create_entity("EmailAddress", {"name" => addr, "origin" => source_uri}) unless addr =~ /.png$|.jpg$|.gif$|.bmp$|.jpeg$/
    end

  end

  def parse_dns_records_from_content(source_uri, content)

    @task_result.logger.log "Parsing text from #{source_uri}" if @task_result

    # Make sure we have something to parse
    unless content
      @task_result.logger.log_error "No content to parse, returning" if @task_result
      return nil
    end

    # Scan for dns records
    dns_records = content.scan(/^[A-Za-z0-9]+\.[A-Za-z0-9]+\.[a-zA-Z]{2,6}$/)
    dns_records.each do |dns_record|
      x = _create_entity("DnsRecord", {"name" => dns_record, "origin" => source_uri})
    end
  end

  def parse_phone_numbers_from_content(source_uri, content)

    @task_result.logger.log "Parsing text from #{source_uri}" if @task_result

    # Make sure we have something to parse
    unless content
      @task_result.logger.log_error "No content to parse, returning" if @task_result
      return nil
    end

    # Scan for phone numbers
    phone_numbers = content.scan(/((\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4})/)
    phone_numbers.each do |phone_number|
      x = _create_entity("PhoneNumber", { "name" => "#{phone_number[0]}", "origin" => source_uri})
    end
  end

  def parse_uris_from_content(source_uri, content)

    @task_result.logger.log "Parsing text from #{source_uri}" if @task_result

    # Make sure we have something to parse
    unless content
      @task_result.logger.log_error "No content to parse, returning" if @task_result
      return nil
    end

    # Scan for uris
    urls = content.scan(/https?:\/\/[\S]+/)
    urls.each do |url|
      _create_entity("Uri", {"name" => url, "uri" => url, "origin" => source_uri })
    end
  end

  def download_and_extract_metadata(uri,extract_content=true)

    uri = uri.gsub(" ","%20")

    begin
      # Download file and store locally before parsing. This helps prevent mime-type confusion
      # Note that we don't care who it is, we'll download indescriminently.
      file = open(uri, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})

      # Parse the file
      yomu = Yomu.new file

      # Handle audio files
      if yomu.metadata["Content-Type"] == "audio/mpeg" # Handle MP3/4
        _create_entity "Person", {"name" => yomu.metadata["meta:author"], "origin" => uri }
        _create_entity "Person", {"name" => yomu.metadata["creator"], "origin" => uri }
        _create_entity "Person", {"name" => yomu.metadata["xmpDM:artist"], "origin" => uri }
      end

      # create a uri for everything
      _create_entity "Uri", {
          "content_type" => file.content_type,
          "name" => "#{uri}",
          "uri" => "#{uri}",
          "metadata" => "#{yomu.metadata.to_json}" }

      # Look for entities in the text of the entity
      parse_entities_from_content(uri,yomu.text) if extract_content

    # Don't die if we lose our connection to the tika server
  rescue RuntimeError => e
      @task_result.logger.log "ERROR Unable to download file: #{e}"
    rescue EOFError => e
      @task_result.logger.log "ERROR Unable to download file: #{e}"
    rescue JSON::ParserError => e
      @task_result.logger.log "ERROR parsing JSON: #{e}"
    rescue Errno::EPIPE => e
      @task_result.logger.log "ERROR Unable to contact Tika: #{e}"
    rescue OpenURI::HTTPError => e     # don't die if we can't find the file
      @task_result.logger.log "ERROR Unable to download file: #{e}"
    rescue URI::InvalidURIError => e     # handle invalid uris
      @task_result.logger.log "ERROR Unable to download file: #{e}"
    end

    # Clean up
    #
    #file.unlink if file
  end


  ###
  ### Expects a string
  ###
  def parse_seals(content)
    #
    # Trustwave Seal
    #
    content.scan(/sealserver.trustwave.com\/seal.js/i).each do |item|
      _create_entity("Info", {"name" => "SecuritySeal: Trustwave #{_get_entity_name}"})
    end
  end

end
end
end
