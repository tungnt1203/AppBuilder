module ProjectsHelper
  # Ideas to start from on the home page: a name and a request the agent can build.
  SUGGESTIONS = [
    { name: "Retro Cat Tees", request: "A print-on-demand shop for funny retro cat T-shirts and hoodies, sizes S to 3XL, in black, white and sand." },
    { name: "Custom Pet Portraits", request: "Buyers upload a photo of their pet and pick a canvas, mug or blanket; we print their pet in a cartoon style." },
    { name: "Fishing Dad Gear", request: "Gifts for dads who love fishing: tees, caps and mugs with fishing jokes. Bundles for Father's Day." },
    { name: "Nurse Life Store", request: "Shirts, tumblers and tote bags for nurses, grouped by specialty (ER, ICU, pediatrics), with a gift section." },
    { name: "Hometown Pride", request: "Tees and posters with US state and city designs. Buyers browse by state and pick shirt color and size." },
    { name: "Christmas Ornaments", request: "Personalized family Christmas ornaments: buyers type up to 6 names and pick a design. Ships before Dec 15." }
  ]

  def suggestions
    SUGGESTIONS
  end

  # A colored tile with the app's initial, until there is a picture of it.
  def monogram(project)
    hue = project.name.to_s.sum % 360
    tag.div(project.name.to_s.strip.first.to_s.upcase, class: "monogram", style: "--hue: #{hue}", "aria-hidden": true)
  end

  # Where a new app is before its first build (Describe, Plan, Build) and what to do next.
  def blank_preview_status(project)
    if project.working?
      [ 1, "The agent is reading your request and working out a plan. Nothing changes in the app yet." ]
    elsif project.latest_proposal
      [ 1, "The plan is ready. Read it in the chat, then press “#{project.approval_message}” and it gets built here." ]
    elsif project.open_reply&.data&.dig("questions").present?
      [ 1, "The agent has a few questions. Answer them in the chat and it carries on." ]
    elsif project.failed?
      [ 0, "The last step didn't finish. Tell the agent in the chat what to try." ]
    else
      [ 0, "Describe the app you want in the chat. The agent plans it with you, then builds it here." ]
    end
  end

  def project_subtitle(project, everyone: false)
    if everyone && project.owner != Current.user
      "By #{project.owner&.name || "nobody yet"} · edited #{time_ago_in_words(project.updated_at)} ago"
    elsif live = project.live_deployment
      "Live at #{project.publish_host}"
    else
      "Edited #{time_ago_in_words(project.updated_at)} ago"
    end
  end
end
