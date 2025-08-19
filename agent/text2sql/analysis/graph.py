import logging

from langgraph.graph import StateGraph
from langgraph.graph.state import CompiledStateGraph

from agent.text2sql.analysis.data_render import data_render
from agent.text2sql.analysis.reasoning import create_reasoning_steps
from agent.text2sql.database.db_service import DatabaseService
from agent.text2sql.sql.generator import sql_generate
from agent.text2sql.state.agent_state import AgentState

logger = logging.getLogger(__name__)

database = DatabaseService()


def create_graph():
    """
    :return:
    """
    graph = StateGraph(AgentState)

    graph.add_node("db_information_schema", database.get_table_schema)
    graph.add_node("reasoning", create_reasoning_steps)
    graph.add_node("sql_generate", sql_generate)
    graph.add_node("execute_sql", database.execute_sql)
    graph.add_node("data_render", data_render)

    graph.set_entry_point("db_information_schema")
    graph.add_edge("db_information_schema", "reasoning")
    graph.add_edge("reasoning", "sql_generate")
    graph.add_edge("sql_generate", "execute_sql")
    graph.add_edge("execute_sql", "data_render")

    graph_compiled: CompiledStateGraph = graph.compile()
    return graph_compiled
