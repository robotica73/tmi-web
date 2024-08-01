# Keywords are the nouns extracted from a 'corpus' consisting of the exact text of
# certain freeform response fields. The extraction is performed using AI assistance,
# so results are nondeterminative and must be assessed for bias by the researchers.

class Keyword

  include ActiveGraph::Node

  property :name

  validates :name, presence: true

  has_many :in, :personas, rel_class: :ReflectsOn, dependent: :delete_orphans

  # This is the prompt passed to the AI agent to serve as instructions for extracting Keywords.
  PROMPT = %{
    Given a text, extract all of the nouns and return them using this JSON example as the format:

    {
      "words" : ["foo", "bar", "baz", "bat]
    }

    The text is as follows:
  }

  # Regenerates Keyword objects based on a the "identity reflection / notes" field.
  # This method uses the Clients::OpenAi client passing the codes as an argument to the prompt.
  # The agent returns an array of nouns, which are then captured as Keyword objects.
  def self.from(survey_response_id)
    return unless survey_response = SurveyResponse.find(survey_response_id.to_i)
    return unless persona = Persona.find_by(survey_response_id: survey_response_id.to_i)

    response = Clients::OpenAi.request("#{PROMPT} #{survey_response.notes}")
    response['words'].compact.map(&:downcase).uniq.each do |word|
      if keyword = Keyword.find_or_create_by(name: word)
        ReflectsOn.create(from_node: persona, to_node: keyword )
      end
    end

  end

end
