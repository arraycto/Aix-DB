import os

from agent.text2sql.state.agent_state import AgentState
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain.chat_models import init_chat_model
from langgraph.prebuilt import create_react_agent


async def data_render(state: AgentState, response):
    """
    数据图表渲染
    :return:
    """
    client = MultiServerMCPClient(
        {
            "mcphub-sse": {
                "url": os.getenv("MCP_HUB_URL"),
                "transport": "streamable_http",
            }
        }
    )

    tools = await client.get_tools()
    llm = init_chat_model(
        model="openai:qwen-plus",
        temperature=0.5,
        base_url=os.getenv("MODEL_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
        api_key=os.getenv("MODEL_API_KEY"),
    )

    user_query = state["user_query"]
    result_data = state["execution_result"]
    reasoning_ = state["sql_reasoning"]

    chart_agent = create_react_agent(
        model=llm,
        tools=tools,
        prompt=f"""
            你是一个经验丰富的BI专家,擅长根据原始数据选择合适的mcp图表工具进行渲染.
            ----
            {result_data}
            ----
          """,
    )

    # result = await chart_agent.ainvoke(
    #     {"messages": [("user", "根据原始数据选择合适的mcp图表工具进行渲染")]},
    #     config={"configurable": {"thread_id": "chart-render"}},
    # )
    #
    # state["chart_url"] = result["messages"][-1].content

    async for message_chunk, metadata in chart_agent.astream(
        input={"messages": [("user", "根据原始数据选择合适的mcp图表工具进行渲染")]},
        config={"configurable": {"thread_id": "chart-render"}},
        stream_mode="messages",
    ):
        # print(message_chunk)
        # 工具输出
        if metadata["langgraph_node"] == "tools":
            tool_name = message_chunk.name or "未知工具"
            tool_use = "> 调用工具:" + tool_name + "\n\n"
            print(tool_use)
            continue

        if message_chunk.content:
            content = message_chunk.content
            print(message_chunk)

    return state
