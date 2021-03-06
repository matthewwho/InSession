require 'json'

class AuthorizationsController < ApplicationController

  def new
    @providers = Provider.all
  end

  def create
    auth_hash = authenticate

    if current_user
      # Means our user is signed in. Add the authorization to the user
      current_user.add_provider(auth_hash)
      url_stub = "/user/exercises"
      request = current_user.oauth_request(auth_hash, url_stub)
      parsed_response = JSON::parse(request.body)

      parsed_response.each do |data|
        unless data["maximum_exercise_progress_"] == "unstarted"
          exercise = Exercise.find_or_create_by(title: data["exercise"])
          user_exercise = UserExercise.where(user_id: current_user.id).find_or_create_by(exercise: exercise)
          if user_exercise.maximum_exercise_progress != data["maximum_exercise_progress_"]
            user_exercise.update(maximum_exercise_progress: data["maximum_exercise_progress_"], last_done: data["last_done"], struggling: data["exercise_states"]["struggling"] )
          end
        end
      end

      active_exercises = UserExercise.where(user_id: current_user.id)
      render :data_landing, locals: {provider: Provider.find_by(name: auth_hash[:provider]), active_exercises: active_exercises, auth_hash: auth_hash}

    else
      raise
      redirect_to "/"
    end
  end

  def authenticate
    auth_hash = request.env['omniauth.auth']
    provider = Provider.find_by(name: auth_hash.provider)
    auth = current_user.authorizations.find_or_create_by(provider: provider)
    auth.user_secret = auth_hash.credentials.secret
    auth.user_token = auth_hash.credentials.token
    auth.uid = auth_hash.credentials.uid
    auth.save
    auth_hash
  end


end
