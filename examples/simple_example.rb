require 'cacheable' # this may not be necessary depending on your autoloading system
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count

  def star_count
    puts 'Fetching data from GitHub'
    url = 'https://api.github.com/repos/splitwise/cacheable'

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end

a = GitHubApiAdapter.new
a.star_count
# Fetching data from GitHub
# => 19
a.star_count
# => 19

a.star_count_without_cache
# Fetching data from GitHub
# => 19
a.star_count
# => 19

a.clear_star_count_cache
# => true
a.star_count
# Fetching data from GitHub
# => 19
