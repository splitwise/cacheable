require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  class << self
    include Cacheable

    cacheable :star_count_for_cacheable, :star_count_for_tokenautocomplete

    def star_count_for_cacheable
      star_count('cacheable')
    end

    private

    def star_count(repo)
      puts "Fetching data from GitHub for #{repo}"
      url = "https://api.github.com/repos/splitwise/#{repo}"

      JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
    end
  end

  def self.star_count_for_tokenautocomplete
    star_count('tokenautocomplete')
  end
end

GitHubApiAdapter.star_count_for_cacheable
# Fetching data from GitHub for cacheable
# => 2
GitHubApiAdapter.star_count_for_cacheable
# => 2

GitHubApiAdapter.star_count_for_tokenautocomplete
# Fetching data from GitHub for tokenautocomplete
# => 1142
GitHubApiAdapter.star_count_for_tokenautocomplete
# => 1142
