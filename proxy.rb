require 'sinatra'
require 'open-uri'
require 'net/http'
require 'psych'

CACHE_FILE = 'cache.yaml'
OFFLINE = true

def update_cache(path, body)
  begin
    cache = Psych.load_file(CACHE_FILE)
  rescue
    cache = {}
  end
  cache[path] = body
  File.open(CACHE_FILE, 'w') do |file|
    file.write(Psych.dump(cache))
  end
  body
end

def cached(path)
  Psych.load_file(CACHE_FILE)[path]
end

def class_for(method)
  return Net::HTTP::Get  if method == :get 
  return Net::HTTP::Post if method == :post
  return Net::HTTP::Put  if method == :put
  throw 'Unknown method'
end

def send_request(method, path, body)
  return cached(path) if OFFLINE
  uri = URI('https://api.github.com' + path)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) {|http|
    req = class_for(method).new(uri)
    req.body = body if body
    req['Authorization'] = request.env['HTTP_AUTHORIZATION']
    http.request(req)
  }
  update_cache(path, res.body)
end

get '*'  do |p| send_request(:get,  p, request.body.read) end
post '*' do |p| send_request(:post, p, request.body.read) end
put '*'  do |p| send_request(:put,  p, request.body.read) end
