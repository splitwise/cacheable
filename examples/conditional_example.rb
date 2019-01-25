require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count, unless: :growing_fast?, key_format: ->(target, method_name, method_args) do
    [target.class, method_name, method_args.first].join('/')
  end

  def star_count(repo)
    puts "Fetching data from GitHub for #{repo}"
    url = "https://api.github.com/repos/splitwise/#{repo}"

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end

  def growing_fast?(_method_name, method_args)
    method_args.first == 'cacheable'
  end
end

a = GitHubApiAdapter.new
a.star_count('tokenautocomplete')
# Fetching data from GitHub for tokenautocomplete
# => 1142
a.star_count('tokenautocomplete')
# => 1142

a.star_count('cacheable')
# Fetching data from GitHub for cacheable
# => 2
a.star_count('cacheable')
# Fetching data from GitHub for cacheable
# => 2
