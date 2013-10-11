class RatingMailer < ActionMailer::Base
  default from: $email_addresses['ArticleMailer']['default_from']

  def bad_seller_notification user
    mail(to: "test@test.de", from: "test2@test.de", subject: "User #{user.id} erhält Status BAD_SELLER")
  end
end