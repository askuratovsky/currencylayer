module OnTimePatch
  def find_rate_for_date(from, to, date)
    date = Date.today unless date.respond_to?(:strftime)

    formated_date = date.strftime('%Y-%m-%d')

    # The only difference is here, as we should also send
    # the specific date query param
    uri = build_uri(from, to)
    uri.query = "#{uri.query}&date=#{formated_date}"

    data = perform_request(uri)
    rate = extract_rate(data, from, to)

    add_rate(from, to, rate)
  end
end
