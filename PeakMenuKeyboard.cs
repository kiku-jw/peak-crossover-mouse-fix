using System;
using System.Collections.Generic;
using System.Collections;
using System.Reflection;
using BepInEx;
using HarmonyLib;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.UI;

namespace PeakMenuKeyboard
{
    [BepInPlugin("nick.peak.menu.keyboard", "Peak Menu Keyboard", "1.3.0")]
    public class PeakMenuKeyboardPlugin : BaseUnityPlugin
    {
        private Harmony _harmony;
        private sealed class MenuCandidate
        {
            public GameObject GameObject;
            public RectTransform RectTransform;
            public Selectable Selectable;
            public Button Button;
            public Component PrimaryComponent;
            public string Description;
        }

        private readonly List<MenuCandidate> _candidates = new List<MenuCandidate>();
        private int _currentIndex = -1;
        private string _lastSignature = string.Empty;
        private float _nextRefreshTime;
        private float _nextEmptyLogTime;
        private float _nextAutoAttemptTime = 4.0f;
        private int _autoAttemptStep;
        private float _nextTargetLogTime;
        private readonly HashSet<string> _queuedAutoInvokes = new HashSet<string>();
        internal static PeakMenuKeyboardPlugin Instance;

        private void Awake()
        {
            Instance = this;
            _harmony = new Harmony("nick.peak.menu.keyboard");
            _harmony.PatchAll();
            Logger.LogInfo("Peak Menu Keyboard loaded");
            Logger.LogInfo("Hotkeys: Enter/E = submit, Tab/WASD/arrows = cycle, F5 = PlayClicked, F6 = PlaySoloClicked, F7 = OnSettingsClicked, F8 = DebugJoinClicked");
        }

        private void Update()
        {
            if (Time.unscaledTime >= _nextRefreshTime)
            {
                RefreshCandidates();
                _nextRefreshTime = Time.unscaledTime + 0.35f;
            }

            HandleDirectMethodHotkeys();
            HandleAutoMenuActions();

            if (_candidates.Count == 0)
            {
                _currentIndex = -1;
                if (Cursor.visible && Time.unscaledTime >= _nextEmptyLogTime)
                {
                    Logger.LogInfo("No active menu candidates found yet");
                    _nextEmptyLogTime = Time.unscaledTime + 5.0f;
                }
                return;
            }

            if (!Cursor.visible)
            {
                return;
            }

            MenuCandidate hoveredCandidate = FindCandidateUnderCursor();
            if (hoveredCandidate != null)
            {
                SetCurrentCandidate(hoveredCandidate);
            }
            else
            {
                SyncCurrentCandidateFromEventSystem();
            }

            EnsureSelectedCandidate();
            HandleNavigation();
            HandleSubmit(hoveredCandidate);
        }

        private void HandleAutoMenuActions()
        {
            if (Time.unscaledTime < _nextAutoAttemptTime)
            {
                return;
            }

            _nextAutoAttemptTime = Time.unscaledTime + 4.0f;

            if (Time.unscaledTime >= _nextTargetLogTime)
            {
                LogKnownTargets();
                _nextTargetLogTime = Time.unscaledTime + 8.0f;
            }

            switch (_autoAttemptStep)
            {
                case 0:
                    if (InvokeNamedAction("PlaySoloClicked") > 0)
                    {
                        _autoAttemptStep++;
                        return;
                    }
                    break;
                case 1:
                    if (InvokeNamedAction("PlayClicked") > 0)
                    {
                        _autoAttemptStep++;
                        return;
                    }
                    break;
                case 2:
                    if (InvokeNamedAction("DebugJoinClicked") > 0)
                    {
                        _autoAttemptStep++;
                        return;
                    }
                    break;
                default:
                    InvokeNamedAction("PlaySoloClicked");
                    break;
            }

            _autoAttemptStep++;
        }

        internal void QueueAutoInvoke(object target, string methodName, float delaySeconds, string source)
        {
            if (target == null)
            {
                return;
            }

            string key = target.GetType().FullName + ":" + methodName;
            if (!_queuedAutoInvokes.Add(key))
            {
                return;
            }

            Logger.LogInfo("Queue auto invoke from " + source + " -> " + key);
            StartCoroutine(InvokeAfterDelay(target, methodName, delaySeconds));
        }

        internal void TryImmediateInvoke(object target, string methodName, string source)
        {
            if (target == null)
            {
                return;
            }

            MethodInfo method = target.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, Type.EmptyTypes, null);
            if (method == null)
            {
                Logger.LogWarning("Immediate invoke method not found from " + source + ": " + target.GetType().FullName + "." + methodName);
                return;
            }

            try
            {
                method.Invoke(target, null);
                Logger.LogInfo("Immediate invoke from " + source + " -> " + target.GetType().FullName + "." + methodName);
            }
            catch (Exception exception)
            {
                Logger.LogWarning("Immediate invoke failed from " + source + " for " + target.GetType().FullName + "." + methodName + ": " + exception.Message);
            }
        }

        private IEnumerator InvokeAfterDelay(object target, string methodName, float delaySeconds)
        {
            yield return new WaitForSecondsRealtime(delaySeconds);

            if (target == null)
            {
                yield break;
            }

            MethodInfo method = target.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, Type.EmptyTypes, null);
            if (method == null)
            {
                Logger.LogWarning("Auto invoke method not found: " + target.GetType().FullName + "." + methodName);
                yield break;
            }

            try
            {
                method.Invoke(target, null);
                Logger.LogInfo("Auto invoke -> " + target.GetType().FullName + "." + methodName);
            }
            catch (Exception exception)
            {
                Logger.LogWarning("Auto invoke failed for " + target.GetType().FullName + "." + methodName + ": " + exception.Message);
            }
        }

        private void LogKnownTargets()
        {
            string[] targetTypes =
            {
                "MainMenu",
                "MainMenuMainPage",
                "MainMenuPlayPage",
                "DebugMainMenu",
                "PauseMenuMainPage",
                "SharedSettingsMenu"
            };

            MonoBehaviour[] behaviours = Resources.FindObjectsOfTypeAll<MonoBehaviour>();
            List<string> found = new List<string>();

            for (int i = 0; i < behaviours.Length; i++)
            {
                MonoBehaviour behaviour = behaviours[i];
                if (!IsUsableBehaviour(behaviour))
                {
                    continue;
                }

                string typeName = behaviour.GetType().Name;
                for (int j = 0; j < targetTypes.Length; j++)
                {
                    if (string.Equals(typeName, targetTypes[j], StringComparison.Ordinal))
                    {
                        found.Add(typeName + ":" + behaviour.gameObject.name);
                    }
                }
            }

            if (found.Count == 0)
            {
                Logger.LogInfo("Known menu targets: none active");
            }
            else
            {
                Logger.LogInfo("Known menu targets: " + string.Join(" | ", found.ToArray()));
            }
        }

        private void RefreshCandidates()
        {
            _candidates.Clear();
            Dictionary<int, MenuCandidate> seen = new Dictionary<int, MenuCandidate>();

            Selectable[] selectables = Selectable.allSelectablesArray;
            for (int i = 0; i < selectables.Length; i++)
            {
                Selectable selectable = selectables[i];
                if (!IsUsableSelectable(selectable))
                {
                    continue;
                }

                AddOrUpdateCandidate(seen, selectable.gameObject, selectable.transform as RectTransform, selectable, selectable as Button, selectable);
            }

            MonoBehaviour[] behaviours = Resources.FindObjectsOfTypeAll<MonoBehaviour>();
            for (int i = 0; i < behaviours.Length; i++)
            {
                MonoBehaviour behaviour = behaviours[i];
                if (!IsUsableBehaviour(behaviour) || !LooksLikeActionComponent(behaviour))
                {
                    continue;
                }

                RectTransform rectTransform = behaviour.transform as RectTransform;
                AddOrUpdateCandidate(seen, behaviour.gameObject, rectTransform, null, null, behaviour);
            }

            _candidates.Sort(CompareCandidates);

            if (_candidates.Count == 0)
            {
                _currentIndex = -1;
                _lastSignature = string.Empty;
                return;
            }

            if (_currentIndex < 0 || _currentIndex >= _candidates.Count)
            {
                _currentIndex = 0;
            }

            string signature = BuildSignature();
            if (!string.Equals(signature, _lastSignature, StringComparison.Ordinal))
            {
                _lastSignature = signature;
                Logger.LogInfo("Active menu candidates: " + signature);
            }
        }

        private void AddOrUpdateCandidate(Dictionary<int, MenuCandidate> seen, GameObject gameObject, RectTransform rectTransform, Selectable selectable, Button button, Component primaryComponent)
        {
            if (gameObject == null || rectTransform == null)
            {
                return;
            }

            int key = gameObject.GetInstanceID();
            MenuCandidate candidate;
            if (!seen.TryGetValue(key, out candidate))
            {
                candidate = new MenuCandidate();
                candidate.GameObject = gameObject;
                candidate.RectTransform = rectTransform;
                candidate.Selectable = selectable;
                candidate.Button = button;
                candidate.PrimaryComponent = primaryComponent;
                candidate.Description = DescribeCandidate(gameObject, primaryComponent);
                seen.Add(key, candidate);
                _candidates.Add(candidate);
                return;
            }

            if (candidate.Selectable == null && selectable != null)
            {
                candidate.Selectable = selectable;
            }

            if (candidate.Button == null && button != null)
            {
                candidate.Button = button;
            }

            if (candidate.PrimaryComponent == null || IsCustomComponent(primaryComponent))
            {
                candidate.PrimaryComponent = primaryComponent;
            }

            candidate.Description = DescribeCandidate(candidate.GameObject, candidate.PrimaryComponent);
        }

        private static bool IsUsableSelectable(Selectable selectable)
        {
            if (selectable == null || !selectable.enabled || !selectable.IsInteractable())
            {
                return false;
            }

            return IsUsableGameObject(selectable.gameObject, selectable.transform as RectTransform);
        }

        private static bool IsUsableBehaviour(MonoBehaviour behaviour)
        {
            if (behaviour == null || !behaviour.enabled)
            {
                return false;
            }

            return IsUsableGameObject(behaviour.gameObject, behaviour.transform as RectTransform);
        }

        private static bool IsUsableGameObject(GameObject gameObject, RectTransform rectTransform)
        {
            if (gameObject == null || rectTransform == null)
            {
                return false;
            }

            if (!gameObject.activeInHierarchy || !gameObject.scene.IsValid())
            {
                return false;
            }

            Canvas canvas = gameObject.GetComponentInParent<Canvas>();
            if (canvas == null || !canvas.isActiveAndEnabled)
            {
                return false;
            }

            Rect rect = rectTransform.rect;
            return rect.width > 0.0f && rect.height > 0.0f;
        }

        private static bool LooksLikeActionComponent(MonoBehaviour behaviour)
        {
            Type type = behaviour.GetType();
            string typeName = type.Name;
            string fullName = type.FullName ?? string.Empty;

            if (typeName.IndexOf("Button", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }

            if (fullName.IndexOf("ModalButtonsOption", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }

            return FindCallableMethod(type) != null;
        }

        private static bool IsCustomComponent(Component component)
        {
            if (component == null)
            {
                return false;
            }

            string ns = component.GetType().Namespace ?? string.Empty;
            return ns.Length > 0 && !ns.StartsWith("UnityEngine", StringComparison.Ordinal);
        }

        private static MethodInfo FindCallableMethod(Type type)
        {
            string[] names =
            {
                "ButtonClicked",
                "OnClick",
                "Click",
                "OnSubmit",
                "Submit",
                "PlayClicked",
                "PlaySoloClicked",
                "OnSettingsClicked",
                "DebugJoinClicked"
            };

            for (int i = 0; i < names.Length; i++)
            {
                MethodInfo method = type.GetMethod(names[i], BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, Type.EmptyTypes, null);
                if (method != null)
                {
                    return method;
                }
            }

            MethodInfo[] methods = type.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            for (int i = 0; i < methods.Length; i++)
            {
                MethodInfo method = methods[i];
                if (method.ReturnType != typeof(void) || method.GetParameters().Length != 0)
                {
                    continue;
                }

                if (method.Name.EndsWith("Clicked", StringComparison.Ordinal))
                {
                    return method;
                }
            }

            return null;
        }

        private static int CompareCandidates(MenuCandidate left, MenuCandidate right)
        {
            Vector3 leftPosition = left.RectTransform.position;
            Vector3 rightPosition = right.RectTransform.position;

            float verticalDelta = rightPosition.y - leftPosition.y;
            if (Mathf.Abs(verticalDelta) > 8.0f)
            {
                return verticalDelta > 0.0f ? 1 : -1;
            }

            float horizontalDelta = leftPosition.x - rightPosition.x;
            if (Mathf.Abs(horizontalDelta) > 8.0f)
            {
                return horizontalDelta > 0.0f ? 1 : -1;
            }

            return string.CompareOrdinal(left.Description, right.Description);
        }

        private string BuildSignature()
        {
            List<string> parts = new List<string>();
            for (int i = 0; i < _candidates.Count; i++)
            {
                parts.Add(_candidates[i].Description);
            }

            return string.Join(" | ", parts.ToArray());
        }

        private static string DescribeCandidate(GameObject gameObject, Component primaryComponent)
        {
            string label = gameObject.name;

            Text labelText = gameObject.GetComponentInChildren<Text>(true);
            if (labelText != null && !string.IsNullOrWhiteSpace(labelText.text))
            {
                label = label + ":" + labelText.text.Trim();
            }

            if (primaryComponent != null)
            {
                label = label + "[" + primaryComponent.GetType().Name + "]";
            }

            return label;
        }

        private MenuCandidate FindCandidateUnderCursor()
        {
            Mouse mouse = Mouse.current;
            if (mouse == null)
            {
                return null;
            }

            Vector2 mousePosition = mouse.position.ReadValue();
            for (int i = 0; i < _candidates.Count; i++)
            {
                MenuCandidate candidate = _candidates[i];
                Canvas canvas = candidate.GameObject.GetComponentInParent<Canvas>();
                Camera worldCamera = null;
                if (canvas != null && canvas.renderMode != RenderMode.ScreenSpaceOverlay)
                {
                    worldCamera = canvas.worldCamera;
                }

                if (RectTransformUtility.RectangleContainsScreenPoint(candidate.RectTransform, mousePosition, worldCamera))
                {
                    return candidate;
                }
            }

            return null;
        }

        private void SyncCurrentCandidateFromEventSystem()
        {
            EventSystem eventSystem = EventSystem.current;
            if (eventSystem == null || eventSystem.currentSelectedGameObject == null)
            {
                return;
            }

            GameObject selected = eventSystem.currentSelectedGameObject;
            for (int i = 0; i < _candidates.Count; i++)
            {
                if (_candidates[i].GameObject == selected)
                {
                    _currentIndex = i;
                    return;
                }
            }
        }

        private void EnsureSelectedCandidate()
        {
            MenuCandidate candidate = GetCurrentCandidate();
            if (candidate == null)
            {
                candidate = _candidates[0];
                _currentIndex = 0;
            }

            EventSystem eventSystem = EventSystem.current;
            if (eventSystem != null && eventSystem.currentSelectedGameObject != candidate.GameObject)
            {
                eventSystem.SetSelectedGameObject(candidate.GameObject);
            }

            if (candidate.Selectable != null)
            {
                candidate.Selectable.Select();
            }
        }

        private void HandleNavigation()
        {
            Keyboard keyboard = Keyboard.current;
            if (keyboard == null)
            {
                return;
            }

            bool shiftPressed = keyboard.leftShiftKey.isPressed || keyboard.rightShiftKey.isPressed;

            if ((keyboard.tabKey.wasPressedThisFrame && !shiftPressed) ||
                keyboard.downArrowKey.wasPressedThisFrame ||
                keyboard.rightArrowKey.wasPressedThisFrame ||
                keyboard.sKey.wasPressedThisFrame ||
                keyboard.dKey.wasPressedThisFrame)
            {
                MoveSelection(1);
            }

            if ((keyboard.tabKey.wasPressedThisFrame && shiftPressed) ||
                keyboard.upArrowKey.wasPressedThisFrame ||
                keyboard.leftArrowKey.wasPressedThisFrame ||
                keyboard.wKey.wasPressedThisFrame ||
                keyboard.aKey.wasPressedThisFrame)
            {
                MoveSelection(-1);
            }
        }

        private void HandleSubmit(MenuCandidate hoveredCandidate)
        {
            Keyboard keyboard = Keyboard.current;
            if (keyboard == null)
            {
                return;
            }

            if (!keyboard.enterKey.wasPressedThisFrame &&
                !keyboard.numpadEnterKey.wasPressedThisFrame &&
                !keyboard.eKey.wasPressedThisFrame)
            {
                return;
            }

            MenuCandidate candidate = hoveredCandidate ?? GetCurrentCandidate();
            if (candidate == null && _candidates.Count > 0)
            {
                candidate = _candidates[0];
                _currentIndex = 0;
            }

            if (candidate == null)
            {
                return;
            }

            SetCurrentCandidate(candidate);
            SubmitCandidate(candidate);
        }

        private void MoveSelection(int direction)
        {
            if (_candidates.Count == 0)
            {
                return;
            }

            if (_currentIndex < 0 || _currentIndex >= _candidates.Count)
            {
                _currentIndex = 0;
            }
            else
            {
                _currentIndex = (_currentIndex + direction + _candidates.Count) % _candidates.Count;
            }

            EnsureSelectedCandidate();
            Logger.LogInfo("Menu selection -> " + _candidates[_currentIndex].Description);
        }

        private void SetCurrentCandidate(MenuCandidate candidate)
        {
            for (int i = 0; i < _candidates.Count; i++)
            {
                if (_candidates[i].GameObject == candidate.GameObject)
                {
                    _currentIndex = i;
                    return;
                }
            }
        }

        private MenuCandidate GetCurrentCandidate()
        {
            if (_currentIndex < 0 || _currentIndex >= _candidates.Count)
            {
                return null;
            }

            return _candidates[_currentIndex];
        }

        private void SubmitCandidate(MenuCandidate candidate)
        {
            EventSystem eventSystem = EventSystem.current;
            if (eventSystem != null)
            {
                eventSystem.SetSelectedGameObject(candidate.GameObject);
                BaseEventData baseEventData = new BaseEventData(eventSystem);
                ExecuteEvents.Execute(candidate.GameObject, baseEventData, ExecuteEvents.submitHandler);

                PointerEventData pointerEventData = new PointerEventData(eventSystem);
                ExecuteEvents.Execute(candidate.GameObject, pointerEventData, ExecuteEvents.pointerClickHandler);
            }

            if (candidate.Button != null)
            {
                candidate.Button.onClick.Invoke();
            }

            InvokeReflectionFallback(candidate.GameObject);
            Logger.LogInfo("Menu submit -> " + candidate.Description);
        }

        private void InvokeReflectionFallback(GameObject gameObject)
        {
            MonoBehaviour[] behaviours = gameObject.GetComponents<MonoBehaviour>();
            for (int i = 0; i < behaviours.Length; i++)
            {
                MonoBehaviour behaviour = behaviours[i];
                if (behaviour == null)
                {
                    continue;
                }

                MethodInfo method = FindCallableMethod(behaviour.GetType());
                if (method == null)
                {
                    continue;
                }

                try
                {
                    method.Invoke(behaviour, null);
                    Logger.LogInfo("Reflection invoke -> " + behaviour.GetType().FullName + "." + method.Name);
                }
                catch (Exception exception)
                {
                    Logger.LogWarning("Reflection invoke failed for " + behaviour.GetType().FullName + "." + method.Name + ": " + exception.Message);
                }
            }
        }

        private void HandleDirectMethodHotkeys()
        {
            if (Pressed(KeyCode.F5, () => Keyboard.current != null && Keyboard.current.f5Key.wasPressedThisFrame))
            {
                InvokeNamedAction("PlayClicked");
            }

            if (Pressed(KeyCode.F6, () => Keyboard.current != null && Keyboard.current.f6Key.wasPressedThisFrame))
            {
                InvokeNamedAction("PlaySoloClicked");
            }

            if (Pressed(KeyCode.F7, () => Keyboard.current != null && Keyboard.current.f7Key.wasPressedThisFrame))
            {
                InvokeNamedAction("OnSettingsClicked");
            }

            if (Pressed(KeyCode.F8, () => Keyboard.current != null && Keyboard.current.f8Key.wasPressedThisFrame))
            {
                InvokeNamedAction("DebugJoinClicked");
            }
        }

        private int InvokeNamedAction(string methodName)
        {
            MonoBehaviour[] behaviours = Resources.FindObjectsOfTypeAll<MonoBehaviour>();
            int invoked = 0;

            for (int i = 0; i < behaviours.Length; i++)
            {
                MonoBehaviour behaviour = behaviours[i];
                if (!IsUsableBehaviour(behaviour))
                {
                    continue;
                }

                MethodInfo method = behaviour.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, Type.EmptyTypes, null);
                if (method == null)
                {
                    continue;
                }

                try
                {
                    method.Invoke(behaviour, null);
                    invoked++;
                    Logger.LogInfo("Direct invoke -> " + behaviour.GetType().FullName + "." + methodName);
                }
                catch (Exception exception)
                {
                    Logger.LogWarning("Direct invoke failed for " + behaviour.GetType().FullName + "." + methodName + ": " + exception.Message);
                }
            }

            if (invoked == 0)
            {
                Logger.LogInfo("Direct invoke found no active targets for " + methodName);
            }

            return invoked;
        }

        private static bool Pressed(KeyCode legacyKey, Func<bool> modernKey)
        {
            if (Input.GetKeyDown(legacyKey))
            {
                return true;
            }

            return modernKey();
        }

        [HarmonyPatch]
        private static class MainMenuStartPatch
        {
            private static MethodBase TargetMethod()
            {
                return AccessTools.Method("MainMenu:Start");
            }

            private static void Postfix(object __instance)
            {
                if (Instance != null)
                {
                    Instance.TryImmediateInvoke(__instance, "PlaySoloClicked", "MainMenu.Start");
                    Instance.QueueAutoInvoke(__instance, "PlaySoloClicked", 1.0f, "MainMenu.Start");
                }
            }
        }

        [HarmonyPatch]
        private static class MainMenuMainPageStartPatch
        {
            private static MethodBase TargetMethod()
            {
                return AccessTools.Method("MainMenuMainPage:Start");
            }

            private static void Postfix(object __instance)
            {
                if (Instance != null)
                {
                    Instance.TryImmediateInvoke(__instance, "PlayClicked", "MainMenuMainPage.Start");
                    Instance.QueueAutoInvoke(__instance, "PlayClicked", 1.0f, "MainMenuMainPage.Start");
                }
            }
        }

        [HarmonyPatch]
        private static class MainMenuPlayPageStartPatch
        {
            private static MethodBase TargetMethod()
            {
                return AccessTools.Method("MainMenuPlayPage:Start");
            }

            private static void Postfix(object __instance)
            {
                if (Instance != null)
                {
                    Instance.TryImmediateInvoke(__instance, "PlayClicked", "MainMenuPlayPage.Start");
                    Instance.QueueAutoInvoke(__instance, "PlayClicked", 1.0f, "MainMenuPlayPage.Start");
                }
            }
        }
    }
}
