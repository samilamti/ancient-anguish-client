#!/usr/bin/env ruby
# App Store sales summary for the client: downloads, updates, re-downloads
# and support-tier subscription units per month, read-only.
#
#   ruby scripts/asc/asc-sales.rb [FROM_MONTH] [TO_MONTH]   e.g. 2026-05 2026-09
#
# WHY THE TEAM KEY: the project's individual key (N9N35R3S5N) gets 403 on
# salesReports and analytics. The team Admin key YDQA9234MV with the team
# issuer works. Vendor number 86330098 (Payments and Financial Reports).
# Product types: 1F iOS first download, F1 Mac first download, 3F/F3
# re-download, 7F/F7 update. Subscription rows carry the pww_* SKUs.
ROOT = File.expand_path("../..", __dir__); VERBOSE = false
ENV["ASC_KEY_PATH"] ||= Dir.glob(File.expand_path("~/.appstoreconnect/private_keys/*YDQA9234MV.p8")).first
ENV["ASC_ISSUER_ID"] ||= "69a6de83-189c-47e3-e053-5b8c7c11a4d1"
require_relative "lib/asc_client"
require "zlib"; require "stringio"; require "date"

VENDOR = ENV["ASC_VENDOR_NUMBER"] || "86330098"
APP_SKU = "org.ancientanguish.ancientAnguishClient"
LABEL = { "1F" => "iOS new", "F1" => "Mac new", "3F" => "iOS redownload", "F3" => "Mac redownload",
          "7F" => "iOS update", "F7" => "Mac update" }

def report(month)
  uri = URI("https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=MONTHLY&filter[reportType]=SALES" \
            "&filter[reportSubType]=SUMMARY&filter[vendorNumber]=#{VENDOR}&filter[reportDate]=#{month}")
  req = Net::HTTP::Get.new(uri); req["Authorization"] = "Bearer #{bearer}"; req["Accept"] = "application/a-gzip"
  res = Net::HTTP.start(uri.host, 443, use_ssl: true) { |h| h.request(req) }
  return nil unless res.code == "200" # 404 = no activity or not published yet
  Zlib::GzipReader.new(StringIO.new(res.body)).read.force_encoding("UTF-8").scrub
end

from = Date.strptime(ARGV[0] || "2026-05", "%Y-%m")
to = Date.strptime(ARGV[1] || (Date.today << 1).strftime("%Y-%m"), "%Y-%m")
m = from
while m <= to
  key = m.strftime("%Y-%m"); t = report(key)
  if t.nil?
    puts "#{key}: no report"
  else
    lines = t.lines.map { |l| l.chomp.split("\t") }; head = lines.shift
    counts = Hash.new(0); proceeds = Hash.new(0.0)
    lines.map { |r| head.zip(r).to_h }.each do |x|
      next unless x["SKU"] == APP_SKU || x["SKU"].to_s.start_with?("pww_")
      k = x["SKU"].start_with?("pww_") ? x["SKU"] : LABEL.fetch(x["Product Type Identifier"], x["Product Type Identifier"])
      counts[k] += x["Units"].to_i
      proceeds[x["Currency of Proceeds"]] += x["Units"].to_i * x["Developer Proceeds"].to_f if x["Developer Proceeds"].to_f > 0
    end
    puts "#{key}: " + counts.sort.map { |k, v| "#{k} #{v}" }.join(", ") +
         (proceeds.empty? ? "" : " | proceeds " + proceeds.map { |c, v| "#{v.round(2)} #{c}" }.join(", "))
  end
  m = m >> 1
end
