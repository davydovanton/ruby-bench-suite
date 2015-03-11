require 'bundler/setup'

require 'benchmark/ips'
require 'json'

require 'rails'
require 'action_controller/railtie'
require 'active_record'
require 'sqlite3'
require 'ffaker'

TIME = (ENV['BENCHMARK_TIME'] || 5).to_i

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :title
    t.string :author
    t.text :body
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
    t.text :body
    t.string :email
    t.string :author
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

5.times do
  post = Post.create!(title: Faker::Name.name, body: Faker::HipsterIpsum.words(50).join(" "))
  2.times do
    post.comments.create(email: Faker::Internet.email, body: Faker::HipsterIpsum.words(50).join(" "), author: Faker::Name.name)
  end
end

report = Benchmark.ips(TIME, quiet: true) do |x|
  x.report("complex script with comments and posts") do
    Post.all

    2.times do
      Post.create!(title: Faker::Food.herb_or_spice, body: Faker::HipsterIpsum.words(50).join(" "), author: Faker::Name.name)
    end

    Post.all.each do |post|
      pos = Post.find(post.id)
      pos.comments.all

      pos.comments.create!(
        body: Faker::HipsterIpsum.words(50).join(" "),
        email: Faker::Internet.email,
        author: Faker::Name.name)

      Post.find(post.id)
      Post.find(post.id).comments.all
      Post.find(post.id).destroy
    end
  end
end

stats = {
  component: :app,
  version: Rails.version.to_s,
  entries: report.entries.map { |e|
    {
      label: e.label,
      iterations: e.iterations,
      ips: e.ips,
      ips_sd: e.ips_sd
    }
  }
}

puts stats.to_json
