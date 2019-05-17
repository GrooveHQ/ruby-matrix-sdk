require 'test_helper'

class UserTest < Test::Unit::TestCase
  def setup
    # Silence debugging output
    ::MatrixSdk.logger.level = :error

    @http = mock
    @http.stubs(:active?).returns(true)

    @api = MatrixSdk::Api.new 'https://example.com', protocols: :CS
    @api.instance_variable_set :@http, @http
    @api.stubs(:print_http)

    @client = MatrixSdk::Client.new @api
    @client.stubs(:mxid).returns('@alice:example.com')

    @id = '@alice:example.com'
    @user = @client.get_user @id
  end

  def test_wrappers
    @api.expects(:get_display_name).with(@id).returns(displayname: nil)
    assert_equal @id, @user.friendly_name

    @api.expects(:get_display_name).with(@id).returns displayname: 'Alice'
    assert_equal 'Alice', @user.display_name
    assert_equal 'Alice', @user.friendly_name

    @api.expects(:set_display_name).with(@id, 'Alice')
    @user.display_name = 'Alice'

    @api.expects(:get_avatar_url).with(@id).returns avatar_url: 'mxc://example.com/avatar'
    assert_equal 'mxc://example.com/avatar', @user.avatar_url

    @api.expects(:set_avatar_url).with(@id, 'mxc://example.com/avatar')
    @user.avatar_url = 'mxc://example.com/avatar'

    data = { device_keys: { @id.to_sym => ['Keys here'] } }
    @api.expects(:keys_query).with(device_keys: { @id => [] }).returns(data)
    assert_equal ['Keys here'], @user.device_keys
  end
end
