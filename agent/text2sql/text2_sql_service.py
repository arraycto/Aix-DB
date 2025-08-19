import asyncio

from agent.text2sql.analysis.graph import create_graph
from agent.text2sql.state.agent_state import AgentState
from langgraph.graph.state import CompiledStateGraph


class Text2SqlAgent:
    """
    文本语言转sql
    """

    def __init__(self):
        pass

    def text2_sql(self, text, response):
        """

        :param text:
        :param response:
        :return:
        """
        initial_state = AgentState(user_query=text, attempts=0, correct_attempts=0)
        graph: CompiledStateGraph = create_graph()
        final_state = asyncio.run(graph.ainvoke(input=initial_state))
