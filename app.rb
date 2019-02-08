#!/usr/bin/env ruby
require 'sinatra'
require 'octokit'
require 'dotenv'
require 'json'

Dotenv.load!

ACCESS_TOKEN = ENV.fetch("GITHUB_ACCESS_TOKEN")

before do
  @client ||= Octokit::Client.new(access_token: ACCESS_TOKEN)
end

post '/event_handler' do
  @payload = JSON.parse(params[:payload])

  case request.env["HTTP_X_GITHUB_EVENT"]
  when "pull_request"
    if @payload["action"] == "opened"
      process_pull_request(@payload["pull_request"])
    else
      puts "Payload action: #{@payload["action"]}"
    end
  when "push"
    puts "In push"
    p @payload
    File.write("tmp.json", @payload.to_json)
    process_push(@payload)
  else
    puts "GitHub event: #{request.env["HTTP_X_GITHUB_EVENT"]}"
  end
end

helpers do
  def process_pull_request(pull_request)
    repo_title = pull_request['title']
    repo_url = pull_request['html_url']

    puts %Q(Processing pull request "#{repo_title}" (#{repo_url})...)

    repo_name = pull_request['base']['repo']['full_name']
    repo_sha = pull_request['head']['sha']
    git_url = pull_request['head']['repo']['git_url']

    options = {
      context: "Simple CI",
      url: "https://b701195d.ngrok.io/builds/#{repo_sha}"
    }

    @client.create_status(repo_name, repo_sha, 'pending', options)
    test_project(git_url, repo_sha)
    @client.create_status(repo_name, repo_sha, 'success', options)

    puts "Pull request processed!"
  end
  
  def process_push(push)
    repo_url = push['repository']['url']
    repo_name = push['repository']['full_name']
    git_url = push['repository']['git_url']
    repo_sha = push['after']

    puts %Q(Processing push to "#{repo_url}")

    options = {
      context: "Simple CI",
      url: "https://b701195d.ngrok.io/builds/#{repo_sha}"
    }

    @client.create_status(repo_name, repo_sha, 'pending', options)
    test_project(git_url, repo_sha)
    @client.create_status(repo_name, repo_sha, 'success', options)

    puts "Push for #{repo_name}:#{repo_sha} processed!"
  end
  
  def enter_temp_dir(&block)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do 
        yield
      end
    end
  end

  def test_project(git_url, repo_sha)
    puts "Testing #{git_url} : #{repo_sha}"

    enter_temp_dir do
      puts `git clone #{git_url} . && echo "Checking out #{repo_sha}" && git checkout #{repo_sha} && bundle && bundle exec rails test`
    end
  end
end
