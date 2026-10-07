# The studio's tour, shown on someone's first visit, ends here: finished or closed, it
# doesn't start by itself again. The "?" button in the studio still shows it.
class ToursController < ApplicationController
  def create
    Current.user.update!(toured_at: Time.current) unless Current.user.toured_at?
    head :no_content
  end
end
