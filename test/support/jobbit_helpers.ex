defmodule Jobbit.JobbitHelpers do

  @spec start_jobbit(any) :: {:ok, [{:sup, pid}, ...]}
  def start_jobbit(_ctx \\ %{}) do
    {:ok, pid} = Jobbit.start_link()
    {:ok, sup: pid}
  end
end
