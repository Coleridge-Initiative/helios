import requests
import time
import pandas as pd
import math
import numpy as np
from json import JSONDecodeError

with open('../data/password.txt', 'r') as myfile:
    password = myfile.read().strip()

login = {
    'username': 'nj995@nyu.edu',
    'password': password
}

def execute_query(string):
    # Send credentials to login url to retrieve token.
    resp = requests.post('https://app.dimensions.ai/api/auth.json', json=login)
    resp.raise_for_status()

    # Create http header using the generated token.
    headers = {'Authorization': "JWT " + resp.json()['token']}

    # Execute DSL query.
    resp = requests.post('https://app.dimensions.ai/api/dsl.json', data=string, headers=headers)

    try:
        resp = resp.json()
    except JSONDecodeError:
        resp = "RESPONSE ERROR"

    return resp

def pull_data(string, in_list, in_type, return_type, max_in_items, max_return, max_overall_returns):

    full_resp = []

    for i in range(math.ceil(len(in_list)/max_in_items)):
        min_i, max_i = i*max_in_items, min((i+1)*max_in_items, len(in_list))
        print('Querying: {}-{}/{} {}...'.format(min_i, max_i, len(in_list), in_type), end = '\r')

        in_t = in_list[min_i:max_i]
        string_t = "\"" + "\", \"".join(in_t) + "\""
        query = string.format(string_t)

        j = 0
        loop = True
        while loop == True:
            query_t = query + " limit {} skip {}".format(max_return, max_return*j)
            resp = execute_query(query_t)
            if resp == "RESPONSE ERROR":
                print("\nRESPONSE ERROR on i={} and j={}.\n".format(i, j))
            else:
                full_resp.extend(resp[return_type])

                if len(resp[return_type])<max_return:
                    loop = False
            j += 1

            if max_return*(j+1)>max_overall_returns:
                loop = False

            time.sleep(2)

        count = resp['_stats']['total_count']
        if resp['_stats']['total_count']>=max_overall_returns:
            print("\nATTENTION! {} {} overall, pulled only {}.\n".format(count, return_type, max_return*j-1))

    print("\nDone !")

    return full_resp
