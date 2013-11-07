class AdminController < ApplicationController
  before_filter :authenticate_user!
  def index
  end

  def addid
  	constructed = Constructed.all
  	constructed.each do |c|
  		currentdeck = Deck.where(:name => c.deckname, :user_id => c.user_id)[0]
  		if currentdeck.nil?
  			c.deck_id = Deck.where(:name => c.deckname)[0]
  		else
	  		c.deck_id = currentdeck.id
	  	end
	  	c.save
  	end
  	redirect_to root_url, notice: 'SUCCESSSS'
  end

  def addprofileuserid
    users = User.all
    users.each do |c|
      p = Profile.new
      p.user_id = c.id
      p.save
    end
    redirect_to root_url, notice: 'SUCCESSSS PROFILE'
  end

end
