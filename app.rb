#!/usr/bin/env ruby
require 'sinatra'
require 'json'

post '/event_handler' do
  payload = JSON.parse(params[:payload])
  "Well, it worked!"
end
