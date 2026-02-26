require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count, key_format: ->(target, method_name, method_args, **kwargs) do
    date = kwargs.fetch(:date, Time.now.strftime('%Y-%m-%d'))
    [target.class, method_name, method_args.first, date].join('/')
  end

  def star_count(repo, date: Time.now.strftime('%Y-%m-%d'))
    puts "Fetching data from GitHub for #{repo} (as of #{date})"
    url = "https://api.github.com/repos/splitwise/#{repo}"

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end

a = GitHubApiAdapter.new
a.star_count('cacheable')
# Fetching data from GitHub for cacheable (as of 2026-02-26)
# => 58
a.star_count('cacheable')
# => 58
a.star_count('tokenautocomplete')
# Fetching data from GitHub for tokenautocomplete (as of 2026-02-26)
# => 1309
a.star_count('tokenautocomplete')
# => 1309
