# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class LabFlowElectronicSignatureTest < ActiveSupport::TestCase
  fixtures :users, :projects, :trackers, :issue_statuses, :issues

  def setup
    @user = User.find(2) # jsmith
    @project = Project.find(1)

    # Ensure Assay tracker exists
    @assay_tracker = Tracker.find_or_create_by!(name: 'Assay') do |t|
      t.default_status = IssueStatus.first
    end

    @issue = Issue.create!(
      project: @project,
      tracker: @assay_tracker,
      subject: 'Test Assay',
      author: @user
    )
  end

  test 'should create signature with valid attributes' do
    signature = LabFlowElectronicSignature.new(
      issue: @issue,
      user: @user,
      signature_meaning: 'authorship',
      signed_at: Time.current
    )
    assert signature.valid?
    assert signature.save
  end

  test 'should require issue' do
    signature = LabFlowElectronicSignature.new(
      user: @user,
      signature_meaning: 'authorship',
      signed_at: Time.current
    )
    assert_not signature.valid?
    assert signature.errors[:issue_id].present?
  end

  test 'should require user' do
    signature = LabFlowElectronicSignature.new(
      issue: @issue,
      signature_meaning: 'authorship',
      signed_at: Time.current
    )
    assert_not signature.valid?
    assert signature.errors[:user_id].present?
  end

  test 'should require valid signature meaning' do
    signature = LabFlowElectronicSignature.new(
      issue: @issue,
      user: @user,
      signature_meaning: 'invalid',
      signed_at: Time.current
    )
    assert_not signature.valid?
    assert signature.errors[:signature_meaning].present?
  end

  test 'should accept valid signature meanings' do
    %w[authorship review approval].each do |meaning|
      signature = LabFlowElectronicSignature.new(
        issue: @issue,
        user: @user,
        signature_meaning: meaning,
        signed_at: Time.current
      )
      assert signature.valid?, "Expected #{meaning} to be valid"
    end
  end

  test 'should auto-set signed_at on create' do
    signature = LabFlowElectronicSignature.create!(
      issue: @issue,
      user: @user,
      signature_meaning: 'authorship'
    )
    assert_not_nil signature.signed_at
  end

  test 'should find recent signature for issue and user' do
    signature = LabFlowElectronicSignature.create!(
      issue: @issue,
      user: @user,
      signature_meaning: 'authorship',
      signed_at: 30.seconds.ago
    )

    found = LabFlowElectronicSignature.recent_signature_for(@issue, @user, seconds: 60)
    assert_equal signature, found
  end

  test 'should not find old signature' do
    LabFlowElectronicSignature.create!(
      issue: @issue,
      user: @user,
      signature_meaning: 'authorship',
      signed_at: 2.minutes.ago
    )

    found = LabFlowElectronicSignature.recent_signature_for(@issue, @user, seconds: 60)
    assert_nil found
  end

  test 'should return meaning label' do
    signature = LabFlowElectronicSignature.new(signature_meaning: 'authorship')
    assert_equal 'Authorship', signature.meaning_label
  end

  test 'should create with password verification' do
    # Set up user password
    @user.password = 'jsmith'
    @user.password_confirmation = 'jsmith'
    @user.save!

    signature = LabFlowElectronicSignature.create_with_verification(
      issue: @issue,
      user: @user,
      password: 'jsmith',
      meaning: 'authorship',
      source_ip: '127.0.0.1'
    )

    assert_not_nil signature
    assert signature.persisted?
    assert_equal '127.0.0.1', signature.source_ip
  end

  test 'should not create with wrong password' do
    @user.password = 'jsmith'
    @user.password_confirmation = 'jsmith'
    @user.save!

    signature = LabFlowElectronicSignature.create_with_verification(
      issue: @issue,
      user: @user,
      password: 'wrong_password',
      meaning: 'authorship'
    )

    assert_nil signature
  end

  test 'should scope by issue' do
    other_issue = Issue.create!(
      project: @project,
      tracker: @assay_tracker,
      subject: 'Other Assay',
      author: @user
    )

    sig1 = LabFlowElectronicSignature.create!(issue: @issue, user: @user, signature_meaning: 'authorship')
    sig2 = LabFlowElectronicSignature.create!(issue: other_issue, user: @user, signature_meaning: 'review')

    signatures = LabFlowElectronicSignature.for_issue(@issue)
    assert_includes signatures, sig1
    assert_not_includes signatures, sig2
  end
end
