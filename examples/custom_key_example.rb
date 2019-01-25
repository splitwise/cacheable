require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count, key_format: ->(target, method_name, method_args) do
    [target.class, method_name, method_args.first, Time.now.strftime('%Y-%m-%d')].join('/')
  end

  def star_count(repo)
    puts "Fetching data from GitHub for #{repo}"
    url = "https://api.github.com/repos/splitwise/#{repo}"

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end

a = GitHubApiAdapter.new
a.star_count('cacheable')
# Fetching data from GitHub for cacheable
# => 19
a.star_count('cacheable')
# => 19
a.star_count('tokenautocomplete')
# Fetching data from GitHub for tokenautocomplete
# => 1164
a.star_count('tokenautocomplete')
# => 1164
