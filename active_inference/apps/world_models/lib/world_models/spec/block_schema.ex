defmodule WorldModels.Spec.BlockSchema do
  @moduledoc """
  Plan §B — per-block parameter schemas for the Builder Inspector.

  Every node type registered in `WorldModels.Spec.Topology` has a schema
  here describing its editable parameters — what type each field is, its
  default, and any range constraints. The Inspector renders a form from
  the schema; `validate/2` round-trips a param map on every change event
  so invalid edits surface inline.

  Schemas are expressed as plain Elixir data (a list of
  `%{name, type, default, required?, min, max, choices, description}`)
  rather than a dependency-heavy macro DSL so the Inspector can render
  them without macro expansion at runtime, and the Builder can persist
  the fields directly into the topology's `:params` map. The shape is
  deliberately close to Zoi's own record shape so a later pass can swap
  this for genuine `Zoi.schema/1` definitions without touching callers.
  """

  @type field :: %{
          required(:name) => atom(),
          required(:type) => :integer | :float | :boolean | :string | :choice | :matrix | :vector,
          required(:default) => any(),
          optional(:required?) => boolean(),
          optional(:min) => number(),
          optional(:max) => number(),
          optional(:choices) => [any()],
          optional(:description) => String.t(),
          optional(:row_labels) => [String.t()],
          optional(:col_labels) => [String.t()]
        }

  @type schema :: %{required(:fields) => [field()], required(:description) => String.t()}

  # -- Per-node schemas -------------------------------------------------------

  @schemas %{
    "bundle" => %{
      description:
        "Generative-model bundle (A/B/C/D). Produced by the assembler in v2; edit raw params here for the monolithic seed.",
      fields: [
        %{
          name: :horizon,
          type: :integer,
          default: 3,
          min: 1,
          max: 20,
          description: "Planning horizon T (number of look-ahead steps)."
        },
        %{
          name: :policy_depth,
          type: :integer,
          default: 3,
          min: 1,
          max: 20,
          description: "Policy depth (branching factor)."
        },
        %{
          name: :preference_strength,
          type: :float,
          default: 4.0,
          min: 0.0,
          max: 20.0,
          description: "Log-odds preference on the goal observation."
        }
      ]
    },
    "archetype" => %{
      description: "Reference to a registry archetype — seeds the full topology.",
      fields: []
    },
    "equation" => %{
      description: "Reference to a registry equation — documentation only.",
      fields: [
        %{
          name: :equation_id,
          type: :string,
          default: "",
          description: "Equation id, e.g. eq_4_13_state_belief_update."
        }
      ]
    },
    "perceive" => %{
      description: "State-belief update (eq 4.13 / B.5).",
      fields: [
        %{
          name: :n_iters,
          type: :integer,
          default: 8,
          min: 1,
          max: 64,
          description: "Mean-field coordinate-ascent iterations per perception step."
        }
      ]
    },
    "plan" => %{
      description: "Policy posterior (eq 4.14 / B.9).",
      fields: [
        %{
          name: :temperature,
          type: :float,
          default: 1.0,
          min: 0.01,
          max: 10.0,
          description: "Softmax temperature for the policy posterior."
        }
      ]
    },
    "act" => %{
      description: "Action emitter — pushes the ActionPacket to the world plane.",
      fields: []
    },
    "likelihood_matrix" => %{
      description:
        "A ∈ ℝ^(|obs| × |states|), column-stochastic. Maps hidden states to observations.",
      fields: [
        %{
          name: :n_obs,
          type: :integer,
          default: 4,
          min: 1,
          max: 64,
          description: "Number of observations (rows)."
        },
        %{
          name: :n_states,
          type: :integer,
          default: 9,
          min: 1,
          max: 256,
          description: "Number of hidden states (columns)."
        },
        %{
          name: :init,
          type: :choice,
          default: "uniform",
          choices: ["uniform", "identity_like", "random", "custom"],
          description: "Initial fill strategy. `custom` uses the :cells matrix."
        },
        %{
          name: :cells,
          type: :matrix,
          default: [],
          description: "2D matrix of probabilities when init = custom."
        }
      ]
    },
    "transition_matrix" => %{
      description: "B ∈ ℝ^(|actions| × |states| × |states|), per-action column-stochastic.",
      fields: [
        %{
          name: :n_states,
          type: :integer,
          default: 9,
          min: 1,
          max: 256,
          description: "Number of hidden states."
        },
        %{
          name: :n_actions,
          type: :integer,
          default: 4,
          min: 1,
          max: 32,
          description: "Number of actions."
        },
        %{
          name: :init,
          type: :choice,
          default: "deterministic_maze",
          choices: ["deterministic_maze", "identity", "uniform", "custom"],
          description: "Initial fill strategy. `deterministic_maze` uses N/S/E/W grid moves."
        }
      ]
    },
    "preference_vector" => %{
      description: "C ∈ ℝ^|obs|, log-odds preferences over observations.",
      fields: [
        %{name: :n_obs, type: :integer, default: 4, min: 1, max: 64},
        %{
          name: :goal_weight,
          type: :float,
          default: 4.0,
          min: 0.0,
          max: 20.0,
          description: "Log-odds mass on the goal observation."
        },
        %{
          name: :epistemic_only?,
          type: :boolean,
          default: false,
          description: "When true, C is zeroed — only the epistemic term of G survives."
        }
      ]
    },
    "prior_vector" => %{
      description: "D ∈ ℝ^|states|, prior over hidden states at t=0.",
      fields: [
        %{name: :n_states, type: :integer, default: 9, min: 1, max: 256},
        %{
          name: :init,
          type: :choice,
          default: "uniform",
          choices: ["uniform", "point_mass", "custom"]
        },
        %{
          name: :point_mass_idx,
          type: :integer,
          default: 0,
          min: 0,
          description: "When init = point_mass, index of the mass."
        }
      ]
    },
    "bundle_assembler" => %{
      description: "Takes A, B, C, D inputs and emits a unified bundle output.",
      fields: []
    },
    "sophisticated_planner" => %{
      description: "Deep-horizon iterative policy search (Ch 7).",
      fields: [
        %{
          name: :horizon,
          type: :integer,
          default: 5,
          min: 1,
          max: 20,
          description: "Planning horizon."
        },
        %{
          name: :tree_policy,
          type: :choice,
          default: "exhaustive",
          choices: ["exhaustive", "beam"]
        },
        %{
          name: :beam_width,
          type: :integer,
          default: 4,
          min: 1,
          max: 64,
          description: "Beam width when tree_policy = beam."
        },
        %{name: :discount, type: :float, default: 0.95, min: 0.0, max: 1.0}
      ]
    },
    "dirichlet_a_learner" => %{
      description: "Online update to A's Dirichlet hyper-params (eq 7.10).",
      fields: [
        %{
          name: :prior_concentration,
          type: :float,
          default: 1.0,
          min: 0.01,
          max: 100.0,
          description: "Initial Dirichlet pseudo-count α₀ before learning starts."
        },
        %{name: :learning_rate, type: :float, default: 1.0, min: 0.0, max: 10.0}
      ]
    },
    "dirichlet_b_learner" => %{
      description: "Online update to B's per-action Dirichlet hyper-params (eq 7.10).",
      fields: [
        %{name: :prior_concentration, type: :float, default: 1.0, min: 0.01, max: 100.0},
        %{name: :learning_rate, type: :float, default: 1.0, min: 0.0, max: 10.0}
      ]
    },
    "epistemic_preference" => %{
      description: "Skill that configures the planner to use epistemic-only G.",
      fields: [
        %{
          name: :epistemic_weight,
          type: :float,
          default: 1.0,
          min: 0.0,
          max: 10.0,
          description: "Weight on the information-gain term."
        },
        %{
          name: :pragmatic_weight,
          type: :float,
          default: 0.0,
          min: 0.0,
          max: 10.0,
          description: "Weight on the preference term (0 for pure curiosity)."
        }
      ]
    },
    "skill" => %{
      description: "Drop-in `Jido.Skill` — pick a registered skill.",
      fields: [
        %{
          name: :module,
          type: :choice,
          default: "ShannonEntropy",
          choices: [
            "ShannonEntropy",
            "KLDivergence",
            "Softmax",
            "CategoricalSample",
            "Argmax",
            "ExpectedFreeEnergy",
            "VariationalFreeEnergy"
          ]
        }
      ]
    },
    "workflow" => %{
      description: "Ordered chain of skills compiled into a `Jido.Workflow` at deploy.",
      fields: [
        %{
          name: :skill_sequence,
          type: :string,
          default: "",
          description: "Comma-separated skill ids in order."
        }
      ]
    },
    "meta_agent" => %{
      description:
        "Hierarchical meta-agent whose policy posterior sets the sub-agent's preference vector.",
      fields: [
        %{name: :sector_count, type: :integer, default: 4, min: 2, max: 64},
        %{name: :macro_horizon, type: :integer, default: 3, min: 1, max: 10}
      ]
    },
    "sub_agent" => %{
      description: "Hierarchical sub-agent receiving preferences from the meta.",
      fields: [
        %{name: :micro_horizon, type: :integer, default: 2, min: 1, max: 10}
      ]
    }
  }

  @spec all() :: %{String.t() => schema()}
  def all, do: @schemas

  @spec fetch(String.t()) :: schema() | nil
  def fetch(type), do: Map.get(@schemas, type)

  @spec defaults(String.t()) :: map()
  def defaults(type) do
    case fetch(type) do
      nil -> %{}
      %{fields: fields} -> Map.new(fields, fn f -> {to_string(f.name), f.default} end)
    end
  end

  @doc """
  Validate a param map against the node-type schema. Returns the coerced
  params (with numeric coercion and defaults applied) plus per-field errors.
  """
  @spec validate(String.t(), map()) :: {map(), %{String.t() => String.t()}}
  def validate(type, params) when is_map(params) do
    case fetch(type) do
      nil ->
        {params, %{}}

      %{fields: fields} ->
        Enum.reduce(fields, {%{}, %{}}, fn field, {ok, errs} ->
          raw = get_param(params, field.name, field.default)

          case coerce(field.type, raw) do
            {:ok, value} ->
              case check_bounds(field, value) do
                :ok ->
                  {Map.put(ok, to_string(field.name), value), errs}

                {:error, msg} ->
                  {Map.put(ok, to_string(field.name), value),
                   Map.put(errs, to_string(field.name), msg)}
              end

            {:error, msg} ->
              {Map.put(ok, to_string(field.name), field.default),
               Map.put(errs, to_string(field.name), msg)}
          end
        end)
    end
  end

  def validate(_type, _params), do: {%{}, %{}}

  defp get_param(params, name, default) do
    Map.get(params, to_string(name)) || Map.get(params, name) || default
  end

  defp coerce(:integer, v) when is_integer(v), do: {:ok, v}

  defp coerce(:integer, v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "expected integer"}
    end
  end

  defp coerce(:integer, _), do: {:error, "expected integer"}

  defp coerce(:float, v) when is_float(v), do: {:ok, v}
  defp coerce(:float, v) when is_integer(v), do: {:ok, v * 1.0}

  defp coerce(:float, v) when is_binary(v) do
    case Float.parse(v) do
      {f, ""} -> {:ok, f}
      _ -> {:error, "expected number"}
    end
  end

  defp coerce(:float, _), do: {:error, "expected number"}

  defp coerce(:boolean, v) when is_boolean(v), do: {:ok, v}
  defp coerce(:boolean, "true"), do: {:ok, true}
  defp coerce(:boolean, "false"), do: {:ok, false}
  defp coerce(:boolean, v) when v in ["on", "1", 1], do: {:ok, true}
  defp coerce(:boolean, v) when v in [nil, "", "0", 0], do: {:ok, false}
  defp coerce(:boolean, _), do: {:ok, false}

  defp coerce(:string, v) when is_binary(v), do: {:ok, v}
  defp coerce(:string, v), do: {:ok, to_string(v)}

  defp coerce(:choice, v) when is_binary(v), do: {:ok, v}
  defp coerce(:choice, v), do: {:ok, to_string(v)}

  defp coerce(:matrix, v) when is_list(v), do: {:ok, v}
  defp coerce(:matrix, _), do: {:ok, []}

  defp coerce(:vector, v) when is_list(v), do: {:ok, v}
  defp coerce(:vector, _), do: {:ok, []}

  defp check_bounds(%{min: min}, v) when is_number(v) and v < min,
    do: {:error, "must be ≥ #{min}"}

  defp check_bounds(%{max: max}, v) when is_number(v) and v > max,
    do: {:error, "must be ≤ #{max}"}

  defp check_bounds(%{choices: choices}, v) do
    if v in choices or to_string(v) in Enum.map(choices, &to_string/1) do
      :ok
    else
      {:error, "must be one of: #{Enum.join(choices, ", ")}"}
    end
  end

  defp check_bounds(_, _), do: :ok
end
