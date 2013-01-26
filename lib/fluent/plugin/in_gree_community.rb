require 'fluent/plugin'
require 'fluent/config'
require 'fluent/input'

1.tap do
  # https://github.com/fluent/fluentd/issues/76
  encoding = Encoding.default_internal
  Encoding.default_internal = nil
  require 'mime/types'
  Encoding.default_internal = encoding
end

require 'gree-community'
require 'pit'

class Fluent::GreeCommunityInput < Fluent::Input
  Fluent::Plugin.register_input('gree_community', self)

  config_param :interval_sec, :integer
  config_param :pit_id, :string
  config_param :community_id, :integer
  config_param :thread_title_pattern, :string
  config_param :tag, :string

  def configure(config)
    super
    @thread_title_pattern = Regexp.new(@thread_title_pattern, {}, 'n')

    user_info = Pit.get(@pit_id, require: {
      'email' => 'mail',
      'password' => 'password',
    })
    @fetcher = GREE::Community::Fetcher.new(
      user_info['email'],
      user_info['password']
    )

    @community = GREE::Community.new(@community_id)

    @last_comment_id = nil

    $log.info("gree_community: user=#{user_info['email']}")
    $log.info("gree_community: community_id=#{@community_id}")
    $log.info("gree_community: thread_title_pattern=#{@thread_title_pattern}")
    $log.info("gree_community: interval_sec=#{@interval_sec}")
  end

  def start
    @thread = Thread.new(&method(:run))
  end

  def shutdown
    @thread.kill
  end

  def run
    loop do
      begin
        fetch_and_emit
      rescue StandardError, Timeout::Error
        $log.error("gree_community: Error!! #{$!} #{$!.backtrace.join("\n")}")
      end
      sleep @interval_sec
    end
  end

  def fetch_and_emit
    @community.fetch(@fetcher)
    @community.recent_threads.select{|th| th.title =~ @thread_title_pattern}.each do|th|
      th.fetch(@fetcher)
      th.recent_comments.each do|comment|
        next if @last_comment_id && comment.id <= @last_comment_id
        @last_comment_id = comment.id
        Fluent::Engine.emit(@tag, Fluent::Engine.now, {
          'community' => {
            'id' => @community.id,
          },
          'thread' => {
            'id' => th.id,
            'title' => th.title,
          },
          'comment' => {
            'id' => comment.id,
            'user_name' => comment.user_name,
            'body_text' => comment.body_text.strip,
          }
        })
      end
    end
  end
end
