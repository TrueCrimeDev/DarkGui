#include <windows.h>
#include <commctrl.h>
#include <uxtheme.h>
#include <vssym32.h>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "uxtheme.lib")

constexpr wchar_t CLASS_NAME[] = L"DarkModeListViewApp";
HWND g_hListView = nullptr;

void InitListView(HWND hwndParent)
{
    RECT rcClient;
    GetClientRect(hwndParent, &rcClient);

    g_hListView = CreateWindowExW(
        0, WC_LISTVIEWW, nullptr,
        WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
        0, 0, rcClient.right, rcClient.bottom,
        hwndParent, nullptr, GetModuleHandleW(nullptr), nullptr
    );

    ListView_SetExtendedListViewStyle(g_hListView, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER);
    SetWindowTheme(g_hListView, L"DarkMode_Explorer", nullptr);

    // Insert column
    LVCOLUMNW lvc = { .mask = LVCF_TEXT | LVCF_WIDTH, .cx = 300, .pszText = const_cast<LPWSTR>(L"Column 1") };
    ListView_InsertColumn(g_hListView, 0, &lvc);

    // Insert item
    LVITEMW lvi = { .mask = LVIF_TEXT, .iItem = 0, .pszText = const_cast<LPWSTR>(L"Item 1") };
    ListView_InsertItem(g_hListView, &lvi);

    ListView_SetBkColor(g_hListView, RGB(0, 0, 0));      // Black background
    ListView_SetTextBkColor(g_hListView, RGB(0, 0, 0));
    ListView_SetTextColor(g_hListView, RGB(255, 255, 255)); // White text
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_CREATE:
        InitListView(hwnd);
        break;

    case WM_NOTIFY:
    {
        LPNMHDR nmhdr = reinterpret_cast<LPNMHDR>(lParam);
        if (nmhdr->code == NM_CUSTOMDRAW && nmhdr->hwndFrom == ListView_GetHeader(g_hListView))
        {
            LPNMCUSTOMDRAW lpDraw = reinterpret_cast<LPNMCUSTOMDRAW>(lParam);
            switch (lpDraw->dwDrawStage)
            {
            case CDDS_PREPAINT:
                return CDRF_NOTIFYITEMDRAW;
            case CDDS_ITEMPREPAINT:
                lpDraw->clrText = RGB(255, 255, 255); // White header text
                lpDraw->clrTextBk = RGB(30, 30, 30);  // Dark header background
                return CDRF_NEWFONT;
            }
        }
    }
    break;

    case WM_SIZE:
        if (g_hListView)
            MoveWindow(g_hListView, 0, 0, LOWORD(lParam), HIWORD(lParam), TRUE);
        break;

    case WM_DESTROY:
        PostQuitMessage(0);
        break;

    default:
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
    return 0;
}

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int nCmdShow)
{
    INITCOMMONCONTROLSEX icex = { sizeof(icex), ICC_LISTVIEW_CLASSES };
    InitCommonControlsEx(&icex);

    WNDCLASSW wc = {};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);

    RegisterClassW(&wc);

    HWND hwnd = CreateWindowExW(
        0, CLASS_NAME, L"Dark Mode ListView",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 600, 400,
        nullptr, nullptr, hInstance, nullptr
    );

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return static_cast<int>(msg.wParam);
}
