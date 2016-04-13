###
# Vocabularies
###

MU_VOTES = RDF::Vocabulary.new('http://mu.semte.ch/vocabularies/ext/votes/')
MU_ACCOUNT = RDF::Vocabulary.new(MU.to_uri.to_s + 'account/')
MU_SESSION = RDF::Vocabulary.new(MU.to_uri.to_s + 'session/')

###
# POST /vote/:id
#
# Body    {"data":{"type":<name-of-type>, "id":<uuid-oftarget> }}
# Returns 200 on ensuring cast vote
#         400 if body is invalid
###
post '/:id' do
  content_type 'application/vnd.api+json'

  request.body.rewind
  body = JSON.parse(request.body.read)
  data = body['data']

  ###
  # Validate request
  ###
  validate_json_api_content_type(request)
  error('Id parameter is required', 403) unless data['id']
  error('Type parameter is required', 403) unless data['type']
  error('Incorrect id. Id does not match the request URL.', 409) if data['id'] != params['id']

  session_uri = session_id_header(request)
  error('Session header is missing') if session_uri.nil?

  register_vote = "
   INSERT {
     GRAPH <#{settings.graph}> {
       ?user <#{MU_VOTES.plus_one}> ?target.
     }
   } WHERE {
     GRAPH <#{settings.graph}> {
       <#{session_uri}> <#{MU_SESSION.account}>/^<#{RDF::Vocab::FOAF.account}> ?user.
       ?target <#{MU_CORE.uuid}> \"#{data['id']}\".
     }
   }
  "

  update register_vote
  update_vote_count( data['id'] )
  status 204
end


###
# DELETE /:id
#
# Returns 204 on successful unregistration of the current account
#         404 if session header is missing or session header is invalid
###
delete '/:id' do
  content_type 'application/vnd.api+json'

  ###
  # Validate request
  ###
  session_uri = session_id_header(request)
  error('Session header is missing') if session_uri.nil?

  remove_vote = "
   DELETE {
     GRAPH <#{settings.graph}> {
       ?user <#{MU_VOTES.plus_one}> ?target.
     }
   }
   WHERE {
     GRAPH <#{settings.graph}> {
       <#{session_uri}> <#{MU_SESSION.account}>/^<#{RDF::Vocab::FOAF.account}> ?user.
       ?target <#{MU_CORE.uuid}> \"#{params['id']}\".
     }
   }
  "

  update remove_vote
  update_vote_count( params['id'] )
  status 204
end

###
# Helpers
###

def update_vote_count( uuid )
  update_vote_count = "
    DELETE {
      GRAPH <#{settings.graph}> {
        ?target <#{MU_VOTES.vote_count}> ?count.
      }
    } WHERE {
      GRAPH <#{settings.graph}> {
        ?target <#{MU_VOTES.vote_count}> ?count.
        ?target <#{MU_CORE.uuid}> \"#{uuid}\".
      }
    }
    INSERT {
      GRAPH <#{settings.graph}> {
        ?target <#{MU_VOTES.vote_count}> ?count.
      }
    }
    WHERE {
      GRAPH <#{settings.graph}> {
        ?target <#{MU_CORE.uuid}> \"#{uuid}\".
        { SELECT count(?user) AS ?count WHERE {
          ?user <#{MU_VOTES.plus_one}> ?target.
        } }
      }
    }"

  update( update_vote_count )
end
