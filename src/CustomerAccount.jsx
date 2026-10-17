import React, { useEffect, useState } from 'react';
import { ArrowRight, Check, Clock3, LogOut, Package, RefreshCw, X } from 'lucide-react';
import { api } from './api';
import { useAuth } from './AuthContext';

const money = paise => `₹${(Number(paise || 0) / 100).toLocaleString('en-IN')}`;
const deliverySteps = ['confirmed', 'processing', 'shipped', 'delivered'];

export default function CustomerAccount({ onClose }) {
  const { configured, user, session, signIn, signUp, signOut } = useAuth();
  const [mode, setMode] = useState('signin');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [account, setAccount] = useState(null);
  const [loadingAccount, setLoadingAccount] = useState(false);
  const [expandedOrder, setExpandedOrder] = useState('');
  const [requestFor, setRequestFor] = useState(null);
  const [requestBusy, setRequestBusy] = useState(false);
  const [refreshingOrders,setRefreshingOrders]=useState(false);

  const loadAccount = async (token, quiet=false) => {
    if(!quiet)setLoadingAccount(true);
    setError('');
    try {
      setAccount(await api('/account', { token }));
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      if(!quiet)setLoadingAccount(false);
    }
  };

  useEffect(() => {
    setAccount(null);
    setError('');
    setMessage('');
    if (user && session?.access_token) loadAccount(session.access_token);
  }, [user?.id, session?.access_token]);

  useEffect(()=>{if(!session?.access_token||!user)return undefined;const timer=setInterval(()=>loadAccount(session.access_token,true),30000);return()=>clearInterval(timer);},[session?.access_token,user?.id]);

  const submitAuth = async event => {
    event.preventDefault();
    setBusy(true);
    setError('');
    setMessage('');
    try {
      if (mode === 'signup') {
        const result = await signUp(name.trim(), email.trim(), password);
        if (!result.session) setMessage('Check your email to confirm your account, then come back to sign in.');
      } else {
        await signIn(email.trim(), password);
      }
    } catch (authError) {
      setError(authError.message || 'We could not sign you in. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  const submitOrderRequest = async event => {
    event.preventDefault();
    if (!session?.access_token || !requestFor) return;
    setRequestBusy(true); setError('');
    const form = new FormData(event.currentTarget);
    try {
      await api(`/account/orders/${encodeURIComponent(requestFor.orderId)}/requests`, { method: 'POST', token: session.access_token, body: JSON.stringify({ type: requestFor.type, itemId: requestFor.itemId || undefined, reason: form.get('reason'), comments: form.get('comments') || '' }) });
      setRequestFor(null); await loadAccount(session.access_token);
    } catch (requestError) { setError(requestError.message); }
    finally { setRequestBusy(false); }
  };

  const handleSignOut = async () => {
    setBusy(true);
    setError('');
    try {
      if(account?.wishlist?.length){const saved=JSON.parse(localStorage.getItem('thara-wishlist')||'[]');localStorage.setItem('thara-wishlist',JSON.stringify(saved.filter(id=>!account.wishlist.includes(id))));window.dispatchEvent(new Event('thara-wishlist-changed'));}
      await signOut();
      setAccount(null);
      setMessage('You’re signed out. Your bag is still here for you.');
      setMode('signin');
      setPassword('');
    } catch (authError) {
      setError(authError.message || 'Could not sign out. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  return <div className="overlay account-overlay" onClick={onClose}>
    <section className="customer-account-modal" role="dialog" aria-modal="true" aria-label="Customer account" onClick={event => event.stopPropagation()}>
      <button className="close-button account-close" aria-label="Close account" onClick={onClose}><X size={19}/></button>
      {!configured ? <div className="account-auth-view">
        <span className="eyebrow"><i/> YOUR TARA ACCOUNT</span>
        <h2>A little more<br/><em>personal.</em></h2>
        <p>Customer sign-in is not connected yet. Add the Supabase project URL and public anon key to the app configuration to enable accounts. You can still shop and check out as a guest.</p>
        <button className="button button-dark" onClick={onClose}>Continue shopping <ArrowRight size={16}/></button>
      </div> : !user ? <div className="account-auth-view">
        <span className="eyebrow"><i/> YOUR TARA ACCOUNT</span>
        <h2>{mode === 'signup' ? <>A lovely place<br/><em>to begin.</em></> : <>Good to have<br/><em>you back.</em></>}</h2>
        <p>Sign in to keep your order history and saved addresses close.</p>
        <form className="account-form" onSubmit={submitAuth}>
          {mode === 'signup' && <label>FULL NAME<input autoComplete="name" required minLength="2" maxLength="120" value={name} onChange={event => setName(event.target.value)}/></label>}
          <label>EMAIL ADDRESS<input type="email" autoComplete="email" required maxLength="254" value={email} onChange={event => setEmail(event.target.value)}/></label>
          <label>PASSWORD<input type="password" autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} required minLength="8" maxLength="128" value={password} onChange={event => setPassword(event.target.value)}/></label>
          {error && <p className="account-error" role="alert">{error}</p>}
          {message && <p className="account-message" role="status">{message}</p>}
          <button className="button button-dark" disabled={busy}>{busy ? 'One little moment…' : mode === 'signup' ? 'Create your account' : 'Sign in'} <ArrowRight size={16}/></button>
        </form>
        <button className="account-switch" onClick={() => { setMode(mode === 'signup' ? 'signin' : 'signup'); setError(''); setMessage(''); }}>{mode === 'signup' ? 'Already have an account? Sign in' : 'New to Tara? Create an account'}</button>
        <small className="account-guest-note">You can always continue as a guest at checkout.</small>
      </div> : <div className="account-dashboard">
        <div className="account-heading"><div><span className="eyebrow"><i/> YOUR TARA ACCOUNT</span><h2>Hello, <em>{user.user_metadata?.full_name?.split(' ')[0] || user.email?.split('@')[0] || 'lovely'}.</em></h2><p>{user.email}</p></div><button className="account-logout" disabled={busy} onClick={handleSignOut}><LogOut size={15}/> Sign out</button></div>
        {error && <p className="account-error" role="alert">{error}</p>}
        {message && <p className="account-message" role="status">{message}</p>}
        {loadingAccount ? <div className="account-loading" role="status">Loading your account…</div> : <>
          <section className="account-section"><div className="account-section-heading"><h3><Package size={16}/> My orders</h3><div className="account-heading-tools"><span>{account?.orders?.length || 0}</span><button aria-label="Refresh order status" disabled={refreshingOrders} onClick={async()=>{setRefreshingOrders(true);await loadAccount(session.access_token);setRefreshingOrders(false);}}><RefreshCw size={14}/>{refreshingOrders?'Updating…':'Refresh'}</button></div></div>
            {account?.orders?.length ? account.orders.map(order => <article className="account-order-card" key={order.id}><button className="account-order" aria-expanded={expandedOrder===order.id} onClick={()=>setExpandedOrder(expandedOrder===order.id?'':order.id)}><div><b>{order.order_number}</b><small>{new Date(order.created_at).toLocaleDateString('en-IN')} · {order.items?.length || 0} item{order.items?.length === 1 ? '' : 's'}</small></div><div><b>{money(order.total_paise)}</b><small>{String(order.status).replaceAll('_', ' ')} · {order.payment_status}</small></div><span className="account-order-more">{expandedOrder===order.id?'See less':'See more'} <ArrowRight size={13}/></span></button>{expandedOrder===order.id&&<div className="account-order-details"><div className="account-order-timeline" aria-label="Order progress">{deliverySteps.map((step,index)=>{const current=deliverySteps.indexOf(order.status);const done=order.status==='delivered'||(current>=0&&current>=index);return <span className={done?'done':''} key={step}><i>{done?<Check size={11}/>:<Clock3 size={11}/>}</i>{step.replace('_',' ')}</span>})}</div>{order.tracking_number&&<p className="account-tracking"><b>{order.courier||'Courier'} tracking:</b> {order.tracking_number}</p>}{order.courier&&<p className="account-order-address">Carrier scan updates are not connected yet; this status refreshes from the store every 30 seconds.</p>}<div className="account-order-items">{order.items?.map(item=><div key={item.id}><span>{item.name} · {item.size||'One size'} × {item.quantity}</span><b>{money(item.unitPricePaise*item.quantity)}</b></div>)}</div><p className="account-order-address"><b>Delivery address</b><br/>{order.address?.line1}{order.address?.line2?`, ${order.address.line2}`:''}, {order.address?.city}, {order.address?.state} {order.address?.pincode}</p>{order.requests?.map(request=><p className="account-request-status" key={request.id}><b>{request.type} · {String(request.status).replaceAll('_',' ')}</b>{request.decisionReason&&` — ${request.decisionReason}`}</p>)}{order.refunds?.map(refund=><p className="account-request-status" key={refund.id}><b>Refund · {String(refund.status).replaceAll('_',' ')}</b> · {money(refund.amountPaise)}</p>)}<div className="account-order-actions">{['pending_payment','confirmed','processing'].includes(order.status)&&<button onClick={()=>setRequestFor({orderId:order.id,type:'cancellation'})}>Request cancellation</button>}{order.status==='delivered'&&order.items?.map(item=><span key={item.id}>{item.name}: <button onClick={()=>setRequestFor({orderId:order.id,itemId:item.id,type:'return'})}>Return</button> · <button onClick={()=>setRequestFor({orderId:order.id,itemId:item.id,type:'exchange'})}>Exchange</button></span>)}</div></div>}</article>) : <p className="account-empty">No account orders yet. Orders placed while signed in will show here.</p>}
          </section>
        </>}
        {requestFor&&<form className="account-request-form" onSubmit={submitOrderRequest}><div><b>{requestFor.type==='cancellation'?'Request cancellation':requestFor.type==='return'?'Request a return':'Request an exchange'}</b><button type="button" aria-label="Close request form" onClick={()=>setRequestFor(null)}><X size={15}/></button></div><label>REASON<select name="reason" required defaultValue=""><option value="" disabled>Choose a reason</option><option>Wrong size or fit</option><option>Damaged or faulty</option><option>Not as expected</option><option>Ordered by mistake</option><option>Other</option></select></label><label>ADDITIONAL DETAILS <span>(OPTIONAL)</span><textarea name="comments" maxLength="1000" rows="3"/></label><p>Requests are reviewed under the store’s current policy. This form does not guarantee approval or a refund.</p><div className="account-address-actions"><button type="button" className="account-cancel" onClick={()=>setRequestFor(null)}>Not now</button><button className="button button-dark" disabled={requestBusy}>{requestBusy?'Sending…':'Send request'} <ArrowRight size={15}/></button></div></form>}
      </div>}
    </section>
  </div>;
}
