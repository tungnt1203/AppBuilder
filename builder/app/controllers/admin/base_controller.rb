# /admin: the owner's admin over all their shops, in its own layout. Signed-in owners use it;
# what's for the builder's administrators says so itself (require_administrator).
class Admin::BaseController < ApplicationController
  layout "admin"
end
