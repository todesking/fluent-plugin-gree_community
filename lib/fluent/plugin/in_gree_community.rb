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
  # Top N threads are watching target
  config_param :recent_threads_num, :integer
  config_param :tag, :string
  config_param :silent_startup, :bool, default: true

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

    # {[community_id, thread_id] => last_comment_id}
    @last_comment_ids = {}

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
    @first_time = true
    loop do
      begin
        fetch_and_emit
      rescue StandardError, Timeout::Error
        $log.error("gree_community(community_id=#{@community_id}): #{$!.inspect}")
        $log.error_backtrace
      end
      @first_time = false
      sleep @interval_sec
    end
  end

  def fetch_and_emit
    @community.fetch(@fetcher)
    @community.recent_threads[0...@recent_threads_num].select{|th| th.title =~ @thread_title_pattern}.each do|th|
      th.fetch(@fetcher)
      th.recent_comments.each do|comment|
        last_comment_id = @last_comment_ids[[@community.id, th.id]]
        next if last_comment_id && comment.id <= last_comment_id
        @last_comment_ids[[@community.id, th.id]] = comment.id

        next if @silent_startup && @first_time

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
            'user_id' => comment.user_id,
            'body_text' => comment.body_text.strip,
          }
        })
      end
    end
  end
end
